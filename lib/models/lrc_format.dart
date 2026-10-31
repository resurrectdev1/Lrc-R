import 'lrc_line.dart';

enum ExportFormat {
  lrc('LRC', 'lrc', 'Line by line'),

  elrc('eLRC', 'elrc', 'Word by word'),

  ttml('TTML', 'ttml', 'Word by word');

  const ExportFormat(this.label, this.extension, this.hint);

  final String label;
  final String extension;
  final String hint;
}

class LyricsMeta {
  final String title;
  final String artist;
  final String album;
  final String by;
  final Duration length;

  const LyricsMeta({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.by = '',
    this.length = Duration.zero,
  });
}

class ParsedLrc {
  final List<LrcLine> lines;

  final bool hasTimestamps;
  final String title;
  final String artist;
  final String album;
  final String by;

  const ParsedLrc({
    required this.lines,
    required this.hasTimestamps,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.by = '',
  });
}

final _lineTs = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');
final _metaTag = RegExp(
  r'^\[(ti|ar|al|by|offset|length):(.*)\]$',
  caseSensitive: false,
);
final _wordTag = RegExp(r'<(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?>');

ParsedLrc parseLrc(String raw) {
  var title = '', artist = '', album = '', by = '';
  final result = <LrcLine>[];
  var foundTimestamp = false;

  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final meta = _metaTag.firstMatch(line);
    if (meta != null) {
      final key = meta.group(1)!.toLowerCase();
      final val = meta.group(2)!.trim();
      if (key == 'ti') title = val;
      if (key == 'ar') artist = val;
      if (key == 'al') album = val;
      if (key == 'by') by = val;
      continue;
    }

    final ts = _lineTs.firstMatch(line);
    if (ts == null) {
      result.add(LrcLine(text: line));
      continue;
    }

    foundTimestamp = true;
    final csStr = ts.group(3)!;
    final timestamp = Duration(
      minutes: int.parse(ts.group(1)!),
      seconds: int.parse(ts.group(2)!),
      milliseconds: csStr.length == 2
          ? int.parse(csStr) * 10
          : int.parse(csStr),
    );
    final text = ts.group(4)!.trim();

    if (_wordTag.hasMatch(text)) {
      final enhanced = _parseEnhancedBody(text, timestamp);
      if (enhanced != null) result.add(enhanced);
    } else if (text.isNotEmpty) {
      result.add(LrcLine(text: text, timestamp: timestamp));
    }
  }

  return ParsedLrc(
    lines: foundTimestamp ? _sortedByTime(result) : const [],
    hasTimestamps: foundTimestamp,
    title: title,
    artist: artist,
    album: album,
    by: by,
  );
}

Duration _tagDuration(RegExpMatch m) {
  final frac = m.group(3);
  return Duration(
    minutes: int.parse(m.group(1)!),
    seconds: int.parse(m.group(2)!),
    milliseconds: frac == null ? 0 : int.parse(frac.padRight(3, '0')),
  );
}

class _WordBuilder {
  String text;
  final Duration start;
  Duration? end;
  _WordBuilder(this.text, this.start);
}

LrcLine? _parseEnhancedBody(String body, Duration lineStart) {
  final matches = _wordTag.allMatches(body).toList();
  final segments = <(Duration, String)>[];

  final lead = body.substring(0, matches.first.start);
  if (lead.trim().isNotEmpty) segments.add((lineStart, lead));
  for (var i = 0; i < matches.length; i++) {
    final stop = i + 1 < matches.length ? matches[i + 1].start : body.length;
    segments.add((
      _tagDuration(matches[i]),
      body.substring(matches[i].end, stop),
    ));
  }

  final words = <_WordBuilder>[];
  _WordBuilder? open;
  _WordBuilder? previous;

  for (final (time, segment) in segments) {
    if (segment.trim().isEmpty) {
      if (previous != null && previous.end == null) previous.end = time;
      open = null;
      continue;
    }
    final startsWithSpace = segment.trimLeft().length != segment.length;
    final endsWithSpace = segment.trimRight().length != segment.length;
    final pieces = splitWords(segment);
    for (var k = 0; k < pieces.length; k++) {
      if (k == 0 && open != null && !startsWithSpace) {
        open.text += pieces[0];
      } else {
        open = _WordBuilder(pieces[k], time);
        words.add(open);
        previous = open;
      }
      if (k < pieces.length - 1 || endsWithSpace) open = null;
    }
  }

  if (words.isEmpty) return null;
  return LrcLine(
    text: words.map((w) => w.text).join(' '),
    timestamp: lineStart,
    words: [for (final w in words) WordTiming(w.start, w.end)],
  );
}

List<LrcLine> _sortedByTime(List<LrcLine> lines) {
  final indexed = [for (var i = 0; i < lines.length; i++) (i, lines[i])];
  indexed.sort((a, b) {
    final ta = a.$2.timestamp, tb = b.$2.timestamp;
    final c = ta == null && tb == null
        ? 0
        : ta == null
        ? 1
        : tb == null
        ? -1
        : ta.compareTo(tb);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

Duration _shift(Duration d, int offsetMs) =>
    Duration(milliseconds: (d.inMilliseconds + offsetMs).clamp(0, 9999999));

Duration? _explicitEnd(
  WordTiming w,
  Duration start,
  Duration? nextStart,
  int offsetMs,
) {
  if (w.end == null) return null;
  var end = _shift(w.end!, offsetMs);
  if (end <= start) return null;
  if (nextStart != null && end > nextStart) end = nextStart;
  return end > start ? end : null;
}

String _minSec(Duration d) {
  final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String buildLrcText(
  List<LrcLine> lines, {
  LyricsMeta meta = const LyricsMeta(),
  int offsetMs = 0,
  bool minimal = false,
  bool enhanced = false,
}) {
  final buf = StringBuffer();
  if (!minimal) {
    if (meta.artist.isNotEmpty) buf.writeln('[ar:${meta.artist}]');
    if (meta.album.isNotEmpty) buf.writeln('[al:${meta.album}]');
    if (meta.title.isNotEmpty) buf.writeln('[ti:${meta.title}]');
    if (meta.by.isNotEmpty) buf.writeln('[by:${meta.by}]');
    if (meta.length > Duration.zero) {
      buf.writeln('[length:${_minSec(meta.length)}]');
    }
    buf.writeln();
  }
  for (final line in _sortedByTime(lines)) {
    if (enhanced && line.hasWordTimings) {
      buf.writeln(_enhancedLine(line, offsetMs));
    } else if (line.timestamp != null) {
      final ts = _shift(line.timestamp!, offsetMs);
      buf.writeln('[${formatLrcTime(ts)}]${line.text}');
    } else {
      buf.writeln(line.text);
    }
  }
  return buf.toString();
}

String _enhancedLine(LrcLine line, int offsetMs) {
  final tokens = line.tokens;
  final timings = line.words!.cast<WordTiming>();
  final starts = [for (final w in timings) _shift(w.start, offsetMs)];
  final last = tokens.length - 1;

  final lineStart = _shift(line.timestamp ?? timings.first.start, offsetMs);
  final b = StringBuffer('[${formatLrcTime(lineStart)}]');
  for (var i = 0; i <= last; i++) {
    b.write('<${formatLrcTime(starts[i])}>${tokens[i]} ');
    final end = _explicitEnd(
      timings[i],
      starts[i],
      i < last ? starts[i + 1] : null,
      offsetMs,
    );
    if (end != null &&
        (i == last || formatLrcTime(end) != formatLrcTime(starts[i + 1]))) {
      b.write('<${formatLrcTime(end)}>');
    }
  }
  return b.toString().trimRight();
}

String _ttmlTime(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final h = (ms ~/ 3600000).toString().padLeft(2, '0');
  final m = ((ms ~/ 60000) % 60).toString().padLeft(2, '0');
  final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
  final f = (ms % 1000).toString().padLeft(3, '0');
  return '$h:$m:$s.$f';
}

final _xmlInvalid = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

String _xml(String s) => s
    .replaceAll(_xmlInvalid, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

const _fallbackLineLength = Duration(seconds: 5);

String buildTtmlText(
  List<LrcLine> lines, {
  LyricsMeta meta = const LyricsMeta(),
  int offsetMs = 0,
  String language = 'und',
}) {
  final timed = _sortedByTime(lines).where((l) => l.timestamp != null).toList();
  final anyWords = timed.any((l) => l.hasWordTimings);

  Duration lineStartAt(int i) => _shift(timed[i].timestamp!, offsetMs);

  final paragraphs = StringBuffer();
  Duration? firstStart, lastEnd;

  for (var i = 0; i < timed.length; i++) {
    final line = timed[i];
    final start = lineStartAt(i);
    final nextLine = i + 1 < timed.length ? lineStartAt(i + 1) : null;
    final fallbackEnd = nextLine != null && nextLine > start
        ? nextLine
        : (meta.length > start ? meta.length : start + _fallbackLineLength);

    final attrs = 'ttm:agent="v1" itunes:key="L${i + 1}"';
    Duration end;
    final body = StringBuffer();

    if (line.hasWordTimings) {
      final tokens = line.tokens;
      final timings = line.words!.cast<WordTiming>();
      final starts = [for (final w in timings) _shift(w.start, offsetMs)];
      final last = tokens.length - 1;
      final ends = <Duration>[];
      for (var j = 0; j <= last; j++) {
        final nextWord = j < last ? starts[j + 1] : nextLine;
        var e =
            _explicitEnd(timings[j], starts[j], nextWord, offsetMs) ??
            (j < last ? starts[j + 1] : fallbackEnd);
        if (e < starts[j]) e = starts[j];
        ends.add(e);
      }
      for (var j = 0; j <= last; j++) {
        if (j > 0) body.write(' ');
        body.write(
          '<span begin="${_ttmlTime(starts[j])}" end="${_ttmlTime(ends[j])}">'
          '${_xml(tokens[j])}</span>',
        );
      }
      end = ends.last;
    } else {
      body.write(_xml(line.text));
      end = fallbackEnd;
    }
    if (end < start) end = start;

    paragraphs.writeln(
      '      <p begin="${_ttmlTime(start)}" end="${_ttmlTime(end)}" $attrs>'
      '$body</p>',
    );
    firstStart ??= start;
    if (lastEnd == null || end > lastEnd) lastEnd = end;
  }

  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<tt xmlns="http://www.w3.org/ns/ttml" '
      'xmlns:ttm="http://www.w3.org/ns/ttml#metadata" '
      'xmlns:itunes="http://music.apple.com/lyric-ttml-internal" '
      'itunes:timing="${anyWords ? 'Word' : 'Line'}" '
      'xml:lang="${_xml(language)}">',
    )
    ..writeln('  <head>')
    ..writeln('    <metadata>');
  if (meta.title.isNotEmpty) {
    out.writeln('      <ttm:title>${_xml(meta.title)}</ttm:title>');
  }
  out
    ..writeln('      <ttm:agent type="person" xml:id="v1"/>')
    ..writeln('    </metadata>')
    ..writeln('  </head>');

  final bodyDur = meta.length > Duration.zero
      ? ' dur="${_ttmlTime(meta.length)}"'
      : '';
  out.writeln('  <body$bodyDur>');
  if (timed.isEmpty) {
    out.writeln('    <div/>');
  } else {
    out
      ..writeln(
        '    <div begin="${_ttmlTime(firstStart!)}" '
        'end="${_ttmlTime(lastEnd!)}">',
      )
      ..write(paragraphs)
      ..writeln('    </div>');
  }
  out
    ..writeln('  </body>')
    ..writeln('</tt>');
  return out.toString();
}
