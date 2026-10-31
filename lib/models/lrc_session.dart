import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/library_scanner.dart';
import 'lrc_format.dart';
import 'lrc_line.dart';

export 'lrc_line.dart';

enum SyncMode { line, word }

sealed class _UndoAction {}

class _TagAction extends _UndoAction {
  final int index;
  final LrcLine previous;
  final int previousTagIndex;
  final int previousWordIndex;
  _TagAction(
    this.index,
    this.previous,
    this.previousTagIndex,
    this.previousWordIndex,
  );
}

class _EditAction extends _UndoAction {
  final int index;
  final LrcLine previous;
  _EditAction(this.index, this.previous);
}

class _DeleteAction extends _UndoAction {
  final int index;
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

class LrcSession extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();

  String? audioPath;
  String? audioName;

  LibraryTrack? currentTrack;
  Duration audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;
  bool isPlaying = false;
  double playbackSpeed = 1.0;

  final Stopwatch _positionClock = Stopwatch();
  Duration _positionAnchor = Duration.zero;
  static const _maxExtrapolationMs = 600;

  List<LrcLine> lines = [];
  String? lyricsRaw;
  int tagIndex = 0;

  SyncMode syncMode = SyncMode.line;

  int wordIndex = 0;

  int _holdLine = -1;
  int _holdWord = -1;
  Duration _holdStart = Duration.zero;

  final List<_UndoAction> _undoStack = [];
  static const _maxUndo = 200;

  String _title = '';
  String _artist = '';
  String _album = '';
  String _by = '';

  String get title => _title;
  String get artist => _artist;
  String get album => _album;
  String get by => _by;

  void setTitle(String v) {
    _title = v;
    notifyListeners();
  }

  void setArtist(String v) {
    _artist = v;
    notifyListeners();
  }

  void setAlbum(String v) {
    _album = v;
    notifyListeners();
  }

  void setBy(String v) {
    _by = v;
    notifyListeners();
  }

  set title(String v) => setTitle(v);
  set artist(String v) => setArtist(v);
  set album(String v) => setAlbum(v);
  set by(String v) => setBy(v);

  LrcSession() {
    WidgetsBinding.instance.addObserver(this);
    _player.onPositionChanged.listen((pos) {
      audioPosition = pos;
      _anchorPosition(pos);
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((state) {
      isPlaying = state == PlayerState.playing;
      _anchorPosition(audioPosition);
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      audioDuration = dur;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) async {
      await _player.seek(Duration.zero);
      isPlaying = false;
      audioPosition = Duration.zero;
      _anchorPosition(Duration.zero);
      notifyListeners();
    });
  }

  void _anchorPosition(Duration at) {
    _positionAnchor = at;
    _positionClock.reset();
    if (isPlaying) _positionClock.start();
  }

  Duration get livePosition {
    if (!isPlaying || !_positionClock.isRunning) return audioPosition;
    final elapsedMs = _positionClock.elapsedMicroseconds / 1000.0;
    final capped = elapsedMs > _maxExtrapolationMs
        ? _maxExtrapolationMs
        : elapsedMs;
    var ms = _positionAnchor.inMilliseconds + (capped * playbackSpeed).round();
    final end = audioDuration.inMilliseconds;
    if (end > 0 && ms > end) ms = end;
    return Duration(milliseconds: ms);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (isPlaying) _player.pause();
    }
  }

  Future<void> loadAudio(String path, String name) async {
    audioPath = path;
    audioName = name;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(DeviceFileSource(path));
    await _player.setPlaybackRate(playbackSpeed);
    notifyListeners();
  }

  Future<bool> openTrack(LibraryTrack track) async {
    await unloadAudio();
    clearLyrics();
    _title = '';
    _artist = '';
    _album = '';
    _by = '';

    await loadAudio(track.path, track.name);
    currentTrack = track;

    for (final path in await _lyricSources(track)) {
      final f = File(path);
      try {
        if (await f.exists()) {
          setLyricsText(await f.readAsString());
          return hasLyrics;
        }
      } catch (_) {}
    }
    notifyListeners();
    return false;
  }

  Future<List<String>> _lyricSources(LibraryTrack track) async {
    final synced = <(String, DateTime)>[];
    for (final path in [track.elrcPath, track.lrcPath]) {
      try {
        final f = File(path);
        if (await f.exists()) synced.add((path, await f.lastModified()));
      } catch (_) {}
    }
    synced.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in synced) e.$1, track.txtPath];
  }

  Future<void> unloadAudio() async {
    await _player.stop();
    await _player.release();
    audioPath = null;
    audioName = null;
    currentTrack = null;
    audioDuration = Duration.zero;
    audioPosition = Duration.zero;
    isPlaying = false;
    notifyListeners();
  }

  Future<void> playPause() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration position) async {
    _anchorPosition(position);
    await _player.seek(position);
  }

  Future<void> skipBack5() => seek(
    Duration(
      milliseconds: (audioPosition.inMilliseconds - 5000).clamp(
        0,
        audioDuration.inMilliseconds,
      ),
    ),
  );

  Future<void> skipForward5() => seek(
    Duration(
      milliseconds: (audioPosition.inMilliseconds + 5000).clamp(
        0,
        audioDuration.inMilliseconds,
      ),
    ),
  );

  Future<void> setSpeed(double speed) async {
    _anchorPosition(livePosition);
    playbackSpeed = speed;
    await _player.setPlaybackRate(speed);
    notifyListeners();
  }

  MetadataConflict? setLyricsText(String raw) {
    lyricsRaw = raw;
    final parsedLrc = parseLrc(raw);
    final parsedTitle = parsedLrc.title;
    final parsedArtist = parsedLrc.artist;
    final parsedAlbum = parsedLrc.album;
    final parsedBy = parsedLrc.by;
    final parsed = parsedLrc.hasTimestamps ? parsedLrc.lines : null;

    if (parsed != null) {
      lines = parsed;
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
    wordIndex = 0;
    _holdLine = -1;
    _undoStack.clear();

    final fileHasMeta =
        parsedTitle.isNotEmpty ||
        parsedArtist.isNotEmpty ||
        parsedAlbum.isNotEmpty;
    final sessionHasMeta =
        _title.isNotEmpty || _artist.isNotEmpty || _album.isNotEmpty;

    if (fileHasMeta && sessionHasMeta) {
      notifyListeners();
      return MetadataConflict(
        fileTitle: parsedTitle,
        fileArtist: parsedArtist,
        fileAlbum: parsedAlbum,
      );
    }

    if (fileHasMeta) {
      if (_title.isEmpty && parsedTitle.isNotEmpty) _title = parsedTitle;
      if (_artist.isEmpty && parsedArtist.isNotEmpty) _artist = parsedArtist;
      if (_album.isEmpty && parsedAlbum.isNotEmpty) _album = parsedAlbum;
    }
    if (_by.isEmpty && parsedBy.isNotEmpty) _by = parsedBy;

    notifyListeners();
    return null;
  }

  void applyMetadataConflict(
    MetadataConflict conflict, {
    required bool replace,
  }) {
    if (replace) {
      if (conflict.fileTitle.isNotEmpty) _title = conflict.fileTitle;
      if (conflict.fileArtist.isNotEmpty) _artist = conflict.fileArtist;
      if (conflict.fileAlbum.isNotEmpty) _album = conflict.fileAlbum;
      notifyListeners();
    }
  }

  void tagCurrentLine() {
    if (tagIndex >= lines.length) return;
    _push(_TagAction(tagIndex, lines[tagIndex], tagIndex, wordIndex));
    lines[tagIndex] = lines[tagIndex].copyWith(
      timestamp: audioPosition,
      clearWords: true,
    );
    tagIndex = (tagIndex + 1).clamp(0, lines.length);
    wordIndex = 0;
    notifyListeners();
  }

  void setSyncMode(SyncMode mode) {
    if (mode == syncMode) return;
    syncMode = mode;
    _holdLine = -1;
    wordIndex = _firstUntimedWord(tagIndex);
    notifyListeners();
  }

  int _firstUntimedWord(int line) {
    if (line < 0 || line >= lines.length) return 0;
    final w = lines[line].words;
    if (w == null) return 0;
    final i = w.indexWhere((e) => e == null);
    return i == -1 ? 0 : i;
  }

  bool tagNextWord() {
    _holdLine = -1;
    return _stampWord(holding: false);
  }

  bool beginHeldWord() => _stampWord(holding: true);

  void endHeldWord() {
    final li = _holdLine, wi = _holdWord, start = _holdStart;
    _holdLine = -1;
    if (li < 0 || li >= lines.length) return;
    final timing = lines[li].words?[wi];
    if (timing == null || timing.start != start) return;
    final end = livePosition;
    final updated = lines[li].withWordEnd(wi, end);
    if (identical(updated, lines[li])) return;
    lines[li] = updated;
    notifyListeners();
  }

  bool _stampWord({required bool holding}) {
    _skipWordlessLines();
    if (tagIndex >= lines.length) return false;
    final line = lines[tagIndex];
    if (wordIndex >= line.wordCount) wordIndex = 0;
    final at = livePosition;

    _push(_TagAction(tagIndex, line, tagIndex, wordIndex));
    lines[tagIndex] = line.withWordStart(wordIndex, at);
    if (holding) {
      _holdLine = tagIndex;
      _holdWord = wordIndex;
      _holdStart = at;
    }

    wordIndex++;
    if (wordIndex >= line.wordCount) {
      tagIndex++;
      wordIndex = 0;
      _skipWordlessLines();
    }
    notifyListeners();
    return true;
  }

  void _skipWordlessLines() {
    while (tagIndex < lines.length && lines[tagIndex].wordCount == 0) {
      tagIndex++;
      wordIndex = 0;
    }
  }

  void setWordCursor(int line, int word) {
    if (line < 0 || line >= lines.length) return;
    tagIndex = line;
    wordIndex = word.clamp(
      0,
      lines[line].wordCount == 0 ? 0 : lines[line].wordCount - 1,
    );
    _holdLine = -1;
    final w = lines[line].words;
    Duration? target;
    if (w != null && wordIndex < w.length) target = w[wordIndex]?.start;
    if (target == null && w != null && wordIndex > 0) {
      target = w[wordIndex - 1]?.start;
    }
    target ??= lines[line].timestamp;
    if (target != null) seek(target);
    notifyListeners();
  }

  int get totalWords => lines.fold(0, (n, l) => n + l.wordCount);
  int get timedWords => lines.fold(0, (n, l) => n + l.timedWordCount);
  bool get hasWordTimings => lines.any((l) => l.hasWordTimings);

  bool undoLast() {
    if (_undoStack.isEmpty) return false;
    final action = _undoStack.removeLast();
    switch (action) {
      case _TagAction a:
        lines[a.index] = a.previous;
        tagIndex = a.previousTagIndex;
        wordIndex = a.previousWordIndex;
        _holdLine = -1;
      case _EditAction a:
        lines[a.index] = a.previous;
      case _DeleteAction a:
        lines.insert(a.index, a.line);
        if (tagIndex >= a.index) {
          tagIndex = (tagIndex + 1).clamp(0, lines.length);
        }
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
    wordIndex = 0;
    _holdLine = -1;
    notifyListeners();
  }

  void editLine(int index, String newText) {
    if (index < 0 || index >= lines.length) return;
    final old = lines[index];
    _push(_EditAction(index, old));
    final sameWords = splitWords(newText).length == old.wordCount;
    lines[index] = LrcLine(
      text: newText,
      timestamp: old.timestamp,
      words: sameWords ? old.words : null,
    );
    if (index == tagIndex && wordIndex >= lines[index].wordCount) wordIndex = 0;
    notifyListeners();
  }

  void deleteLine(int index) {
    if (index < 0 || index >= lines.length) return;
    _push(_DeleteAction(index, lines[index]));
    final cursorWasOnIt = tagIndex == index;
    lines.removeAt(index);
    if (tagIndex > index) tagIndex = (tagIndex - 1).clamp(0, lines.length);
    if (cursorWasOnIt) wordIndex = 0;
    _holdLine = -1;
    for (var i = _undoStack.length - 1; i >= 0; i--) {
      final a = _undoStack[i];
      if ((a is _TagAction && a.index == index) ||
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
    wordIndex = 0;
    _holdLine = -1;
    _undoStack.clear();
    notifyListeners();
  }

  void clearLyrics() {
    lines = [];
    lyricsRaw = null;
    tagIndex = 0;
    wordIndex = 0;
    _holdLine = -1;
    _undoStack.clear();
    notifyListeners();
  }

  LyricsMeta get _meta => LyricsMeta(
    title: _title,
    artist: _artist,
    album: _album,
    by: _by,
    length: audioDuration,
  );

  String buildLrc({int offsetMs = 0, bool minimal = false}) =>
      buildLrcText(lines, meta: _meta, offsetMs: offsetMs, minimal: minimal);

  String buildExport(
    ExportFormat format, {
    int offsetMs = 0,
    bool minimal = false,
  }) => switch (format) {
    ExportFormat.lrc => buildLrc(offsetMs: offsetMs, minimal: minimal),
    ExportFormat.elrc => buildLrcText(
      lines,
      meta: _meta,
      offsetMs: offsetMs,
      minimal: minimal,
      enhanced: true,
    ),
    ExportFormat.ttml => buildTtmlText(lines, meta: _meta, offsetMs: offsetMs),
  };

  static const _draftKey = 'lrc_r_draft';

  Future<bool> hasDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return false;
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
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'title': _title,
        'artist': _artist,
        'album': _album,
        'by': _by,
        'audioName': audioName,
        'tagIndex': tagIndex,
        'wordIndex': wordIndex,
        'syncMode': syncMode.name,
        'lines': lines
            .map(
              (l) => {
                'text': l.text,
                'timestamp': l.timestamp?.inMilliseconds,
                if (l.words != null)
                  'words': [
                    for (final w in l.words!)
                      w == null
                          ? null
                          : [w.start.inMilliseconds, w.end?.inMilliseconds],
                  ],
              },
            )
            .toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<bool> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return false;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      _title = (json['title'] as String?) ?? '';
      _artist = (json['artist'] as String?) ?? '';
      _album = (json['album'] as String?) ?? '';
      _by = (json['by'] as String?) ?? '';
      audioName = json['audioName'] as String?;

      final linesJson = (json['lines'] as List?) ?? [];
      lines = linesJson.map((e) {
        final map = e as Map<String, dynamic>;
        final ms = map['timestamp'] as int?;
        final text = map['text'] as String? ?? '';
        final wordsJson = map['words'] as List?;
        List<WordTiming?>? words;
        if (wordsJson != null && wordsJson.length == splitWords(text).length) {
          words = [
            for (final w in wordsJson)
              w == null
                  ? null
                  : WordTiming(
                      Duration(milliseconds: (w as List)[0] as int),
                      w[1] == null ? null : Duration(milliseconds: w[1] as int),
                    ),
          ];
        }
        return LrcLine(
          text: text,
          timestamp: ms != null ? Duration(milliseconds: ms) : null,
          words: ms != null ? words : null,
        );
      }).toList();

      tagIndex = (json['tagIndex'] as int?) ?? 0;
      tagIndex = tagIndex.clamp(0, lines.length);
      wordIndex = (json['wordIndex'] as int?) ?? 0;
      syncMode = json['syncMode'] == SyncMode.word.name
          ? SyncMode.word
          : SyncMode.line;
      _holdLine = -1;
      _undoStack.clear();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> discardDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void _push(_UndoAction action) {
    _undoStack.add(action);
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
  }

  int get taggedCount => lines.where((l) => l.isTagged).length;
  int get totalLines => lines.length;
  bool get hasAudio => audioPath != null;
  bool get hasLyrics => lines.isNotEmpty;
  bool get canExport => hasAudio && hasLyrics && taggedCount > 0;

  String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}
