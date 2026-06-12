import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class LrcLine {
  final String   text;
  final Duration? timestamp;

  const LrcLine({required this.text, this.timestamp});

  LrcLine copyWith({String? text, Duration? timestamp, bool clearTimestamp = false}) =>
  LrcLine(
    text:      text ?? this.text,
    timestamp: clearTimestamp ? null : (timestamp ?? this.timestamp),
  );

  String get lrcTimestamp {
    if (timestamp == null) return '';
    final m  = timestamp!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = timestamp!.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (timestamp!.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$m:$s.$cs]';
  }

  bool get isTagged => timestamp != null;
}

sealed class _UndoAction {}

class _TagAction extends _UndoAction {
  final int      index;
  final Duration timestamp;
  _TagAction(this.index, this.timestamp);
}

class _EditAction extends _UndoAction {
  final int    index;
  final String previousText;
  _EditAction(this.index, this.previousText);
}

class _DeleteAction extends _UndoAction {
  final int     index;
  final LrcLine line;
  _DeleteAction(this.index, this.line);
}

class _MoveAction extends _UndoAction {
  final int oldIndex;
  final int newIndex;
  _MoveAction(this.oldIndex, this.newIndex);
}

class MetadataConflict {
  final String fileTitle;
  final String fileArtist;
  final String fileAlbum;
  const MetadataConflict({
    required this.fileTitle,
    required this.fileArtist,
    required this.fileAlbum,
  });
}

class LrcSession extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String?  audioPath;
  String?  audioName;
  Duration audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;
  bool     isPlaying     = false;
  double   playbackSpeed = 1.0;

  List<LrcLine>   lines    = [];
  String?         lyricsRaw;
  int             tagIndex = 0;

  final List<_UndoAction> _undoStack = [];
  static const _maxUndo = 20;

  String _title  = '';
  String _artist = '';
  String _album  = '';

  String get title  => _title;
  String get artist => _artist;
  String get album  => _album;

  void setTitle(String v)  { _title  = v; notifyListeners(); }
  void setArtist(String v) { _artist = v; notifyListeners(); }
  void setAlbum(String v)  { _album  = v; notifyListeners(); }

  set title(String v)  => setTitle(v);
  set artist(String v) => setArtist(v);
  set album(String v)  => setAlbum(v);

  LrcSession() {
    _player.onPositionChanged.listen((pos) {
      audioPosition = pos;
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((state) {
      isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      audioDuration = dur;
      notifyListeners();
    });
  }

  Future<void> loadAudio(String path, String name) async {
    audioPath = path;
    audioName = name;
    await _player.setSource(DeviceFileSource(path));
    await _player.setPlaybackRate(playbackSpeed);
    notifyListeners();
  }

  Future<void> unloadAudio() async {
    await _player.stop();
    await _player.release();
    audioPath     = null;
    audioName     = null;
    audioDuration = Duration.zero;
    audioPosition = Duration.zero;
    isPlaying     = false;
    notifyListeners();
  }

  Future<void> playPause() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> skipBack5() => _player.seek(
    Duration(milliseconds: (audioPosition.inMilliseconds - 5000)
    .clamp(0, audioDuration.inMilliseconds)));

  Future<void> skipForward5() => _player.seek(
    Duration(milliseconds: (audioPosition.inMilliseconds + 5000)
    .clamp(0, audioDuration.inMilliseconds)));

  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
    await _player.setPlaybackRate(speed);
    notifyListeners();
  }

  MetadataConflict? setLyricsText(String raw) {
    lyricsRaw = raw;
    String parsedTitle  = '';
    String parsedArtist = '';
    String parsedAlbum  = '';
    final parsed = _parseLrc(
      raw,
      outTitle:  (v) => parsedTitle  = v,
      outArtist: (v) => parsedArtist = v,
      outAlbum:  (v) => parsedAlbum  = v,
    );

    if (parsed != null) {
      lines    = parsed;
      tagIndex = lines.indexWhere((l) => !l.isTagged);
      if (tagIndex == -1) tagIndex = lines.length;
    } else {
      lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => LrcLine(text: l))
      .toList();
      tagIndex = 0;
    }
    _undoStack.clear();

    final fileHasMeta = parsedTitle.isNotEmpty || parsedArtist.isNotEmpty || parsedAlbum.isNotEmpty;
    final sessionHasMeta = _title.isNotEmpty || _artist.isNotEmpty || _album.isNotEmpty;

    if (fileHasMeta && sessionHasMeta) {
      notifyListeners();
      return MetadataConflict(
        fileTitle:  parsedTitle,
        fileArtist: parsedArtist,
        fileAlbum:  parsedAlbum,
      );
    }

    if (fileHasMeta) {
      if (_title.isEmpty  && parsedTitle.isNotEmpty)  _title  = parsedTitle;
      if (_artist.isEmpty && parsedArtist.isNotEmpty) _artist = parsedArtist;
      if (_album.isEmpty  && parsedAlbum.isNotEmpty)  _album  = parsedAlbum;
    }

    notifyListeners();
    return null;
  }

  void applyMetadataConflict(MetadataConflict conflict, {required bool replace}) {
    if (replace) {
      if (conflict.fileTitle.isNotEmpty)  _title  = conflict.fileTitle;
      if (conflict.fileArtist.isNotEmpty) _artist = conflict.fileArtist;
      if (conflict.fileAlbum.isNotEmpty)  _album  = conflict.fileAlbum;
      notifyListeners();
    }
  }

  List<LrcLine>? _parseLrc(
    String raw, {
      required void Function(String) outTitle,
      required void Function(String) outArtist,
      required void Function(String) outAlbum,
    }) {
    final tsPattern   = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');
    final metaPattern = RegExp(r'^\[(ti|ar|al|by|offset):(.*)\]$', caseSensitive: false);

    final result        = <LrcLine>[];
    bool foundTimestamp = false;

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final meta = metaPattern.firstMatch(line);
      if (meta != null) {
        final key = meta.group(1)!.toLowerCase();
        final val = meta.group(2)!.trim();
        if (key == 'ti') outTitle(val);
        if (key == 'ar') outArtist(val);
        if (key == 'al') outAlbum(val);
        continue;
      }

      final ts = tsPattern.firstMatch(line);
      if (ts != null) {
        foundTimestamp = true;
        final mins  = int.parse(ts.group(1)!);
        final secs  = int.parse(ts.group(2)!);
        final csStr = ts.group(3)!;
        final ms    = csStr.length == 2 ? int.parse(csStr) * 10 : int.parse(csStr);
        final timestamp = Duration(minutes: mins, seconds: secs, milliseconds: ms);
        final text      = ts.group(4)!.trim();
        if (text.isNotEmpty) result.add(LrcLine(text: text, timestamp: timestamp));
      } else {
        result.add(LrcLine(text: line));
      }
    }

    if (!foundTimestamp) return null;
    result.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return a.timestamp!.compareTo(b.timestamp!);
    });
    return result;
    }

    void tagCurrentLine() {
      if (tagIndex >= lines.length) return;
      _push(_TagAction(tagIndex, audioPosition));
      lines[tagIndex] = lines[tagIndex].copyWith(timestamp: audioPosition);
      tagIndex = (tagIndex + 1).clamp(0, lines.length);
      notifyListeners();
    }

    bool undoLast() {
      if (_undoStack.isEmpty) return false;
      final action = _undoStack.removeLast();
      switch (action) {
        case _TagAction a:
          lines[a.index] = lines[a.index].copyWith(clearTimestamp: true);
          tagIndex = a.index;
        case _EditAction a:
          lines[a.index] = lines[a.index].copyWith(text: a.previousText);
        case _DeleteAction a:
          lines.insert(a.index, a.line);
          if (tagIndex >= a.index) tagIndex = (tagIndex + 1).clamp(0, lines.length);
        case _MoveAction a:
          _moveLine(a.newIndex, a.oldIndex, pushUndo: false);
      }
      notifyListeners();
      return true;
    }

    bool undoLastTag() => undoLast();

    bool get canUndo => _undoStack.isNotEmpty;

    void untag(int index) {
      if (index < 0 || index >= lines.length) return;
      lines[index] = lines[index].copyWith(clearTimestamp: true);
      notifyListeners();
    }

    void setTagIndex(int index) {
      tagIndex = index.clamp(0, lines.length);
      notifyListeners();
    }

    void editLine(int index, String newText) {
      if (index < 0 || index >= lines.length) return;
      _push(_EditAction(index, lines[index].text));
      lines[index] = lines[index].copyWith(text: newText);
      notifyListeners();
    }

    void deleteLine(int index) {
      if (index < 0 || index >= lines.length) return;
      _push(_DeleteAction(index, lines[index]));
      lines.removeAt(index);
      if (tagIndex > index) tagIndex = (tagIndex - 1).clamp(0, lines.length);
      for (var i = _undoStack.length - 1; i >= 0; i--) {
        final a = _undoStack[i];
        if ((a is _TagAction  && a.index == index) ||
          (a is _EditAction && a.index == index)) {
          _undoStack.removeAt(i);
          }
      }
      notifyListeners();
    }

    void moveLine(int oldIndex, int newIndex) {
      _moveLine(oldIndex, newIndex, pushUndo: true);
      notifyListeners();
    }

    void _moveLine(int oldIndex, int newIndex, {required bool pushUndo}) {
      if (oldIndex == newIndex) return;
      if (oldIndex < 0 || oldIndex >= lines.length) return;
      if (newIndex < 0 || newIndex >= lines.length) return;
      if (pushUndo) _push(_MoveAction(oldIndex, newIndex));
      final line = lines.removeAt(oldIndex);
      lines.insert(newIndex, line);
      if (tagIndex == oldIndex) {
        tagIndex = newIndex;
      } else if (oldIndex < newIndex) {
        if (tagIndex > oldIndex && tagIndex <= newIndex) tagIndex--;
      } else {
        if (tagIndex >= newIndex && tagIndex < oldIndex) tagIndex++;
      }
    }

    void addLine(int afterIndex, {String text = ''}) {
      final insertAt = (afterIndex + 1).clamp(0, lines.length);
      lines.insert(insertAt, LrcLine(text: text));
      notifyListeners();
    }

    void resetAllTags() {
      lines = lines.map((l) => l.copyWith(clearTimestamp: true)).toList();
      tagIndex = 0;
      _undoStack.clear();
      notifyListeners();
    }

    void clearLyrics() {
      lines     = [];
      lyricsRaw = null;
      tagIndex  = 0;
      _undoStack.clear();
      notifyListeners();
    }

    String buildLrc({int offsetMs = 0}) {
      final buf = StringBuffer();
      if (_title.isNotEmpty)  buf.writeln('[ti:$_title]');
      if (_artist.isNotEmpty) buf.writeln('[ar:$_artist]');
      if (_album.isNotEmpty)  buf.writeln('[al:$_album]');
      buf.writeln('[by:Lrc-R]');
      buf.writeln();
      final sorted = [...lines]..sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return a.timestamp!.compareTo(b.timestamp!);
      });
      for (final line in sorted) {
        if (line.timestamp != null && offsetMs != 0) {
          final shifted = Duration(
            milliseconds: (line.timestamp!.inMilliseconds + offsetMs).clamp(0, 9999999));
          final shiftedLine = line.copyWith(timestamp: shifted);
          buf.writeln('${shiftedLine.lrcTimestamp}${line.text}');
        } else {
          buf.writeln('${line.lrcTimestamp}${line.text}');
        }
      }
      return buf.toString();
    }

    static const _draftFileName = 'lrc_r_draft.json';

    Future<File> _draftFile() async {
      final dir = await getTemporaryDirectory();
      return File('${dir.path}/$_draftFileName');
    }

    Future<bool> hasDraft() async {
      try {
        final file = await _draftFile();
        if (!await file.exists()) return false;
        final raw  = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final linesJson = json['lines'] as List?;
        return linesJson != null && linesJson.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    Future<void> saveDraft() async {
      if (lines.isEmpty) return;
      try {
        final file = await _draftFile();
        final data = {
          'title':    _title,
          'artist':   _artist,
          'album':    _album,
          'audioName': audioName,
          'tagIndex': tagIndex,
          'lines': lines.map((l) => {
            'text':      l.text,
            'timestamp': l.timestamp?.inMilliseconds,
          }).toList(),
        };
        await file.writeAsString(jsonEncode(data));
      } catch (_) {
      }
    }

    Future<bool> loadDraft() async {
      try {
        final file = await _draftFile();
        if (!await file.exists()) return false;
        final raw  = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;

        _title  = (json['title']  as String?) ?? '';
        _artist = (json['artist'] as String?) ?? '';
        _album  = (json['album']  as String?) ?? '';
        audioName = json['audioName'] as String?;

        final linesJson = (json['lines'] as List?) ?? [];
        lines = linesJson.map((e) {
          final map = e as Map<String, dynamic>;
          final ms  = map['timestamp'] as int?;
          return LrcLine(
            text:      map['text'] as String? ?? '',
            timestamp: ms != null ? Duration(milliseconds: ms) : null,
          );
        }).toList();

        tagIndex = (json['tagIndex'] as int?) ?? 0;
        tagIndex = tagIndex.clamp(0, lines.length);
        _undoStack.clear();
        notifyListeners();
        return true;
      } catch (_) {
        return false;
      }
    }

    Future<void> discardDraft() async {
      try {
        final file = await _draftFile();
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    void _push(_UndoAction action) {
      _undoStack.add(action);
      if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    }

    int  get taggedCount => lines.where((l) => l.isTagged).length;
    int  get totalLines  => lines.length;
    bool get hasAudio    => audioPath != null;
    bool get hasLyrics   => lines.isNotEmpty;
    bool get canExport   => hasAudio && hasLyrics && taggedCount > 0;

    String formatDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    @override
    void dispose() {
      _player.dispose();
      super.dispose();
    }
}
