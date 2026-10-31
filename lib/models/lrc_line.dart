List<String> splitWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String formatLrcTime(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final m = (ms ~/ 60000).toString().padLeft(2, '0');
  final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
  final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$m:$s.$cs';
}

class WordTiming {
  final Duration start;
  final Duration? end;

  const WordTiming(this.start, [this.end]);

  WordTiming withEnd(Duration? end) => WordTiming(start, end);

  @override
  bool operator ==(Object other) =>
      other is WordTiming && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'WordTiming($start, $end)';
}

class LrcLine {
  final String text;
  final Duration? timestamp;

  final List<WordTiming?>? words;

  const LrcLine({required this.text, this.timestamp, this.words});

  LrcLine copyWith({
    String? text,
    Duration? timestamp,
    List<WordTiming?>? words,
    bool clearTimestamp = false,
    bool clearWords = false,
  }) => LrcLine(
    text: text ?? this.text,
    timestamp: clearTimestamp ? null : (timestamp ?? this.timestamp),
    words: (clearTimestamp || clearWords) ? null : (words ?? this.words),
  );

  String get lrcTimestamp {
    if (timestamp == null) return '';
    return '[${formatLrcTime(timestamp!)}]';
  }

  bool get isTagged => timestamp != null;

  List<String> get tokens => splitWords(text);

  int get wordCount => tokens.length;

  int get timedWordCount => words?.whereType<WordTiming>().length ?? 0;

  bool get hasWordTimings {
    final w = words;
    if (w == null || w.isEmpty) return false;
    return w.length == wordCount && w.every((e) => e != null);
  }

  LrcLine withWordStart(int index, Duration start) {
    final n = wordCount;
    if (index < 0 || index >= n) return this;
    final current = words;
    final list = (current != null && current.length == n)
        ? List<WordTiming?>.of(current)
        : List<WordTiming?>.filled(n, null);
    list[index] = WordTiming(start);
    return LrcLine(
      text: text,
      timestamp: index == 0 ? start : timestamp,
      words: list,
    );
  }

  LrcLine withWordEnd(int index, Duration end) {
    final w = words;
    if (w == null || index < 0 || index >= w.length) return this;
    final current = w[index];
    if (current == null || end <= current.start) return this;
    final list = List<WordTiming?>.of(w);
    list[index] = current.withEnd(end);
    return LrcLine(text: text, timestamp: timestamp, words: list);
  }
}
