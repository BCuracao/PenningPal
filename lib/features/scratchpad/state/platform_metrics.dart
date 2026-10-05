import 'scratchpad_state.dart';

/// Social network the scratchpad HUD is measuring.
enum SocialPlatform { linkedIn, x, threads }

/// Green, amber, or red fill for a platform character meter.
enum LimitTone { safe, caution, overflow }

/// One platform's live character meter.
class PlatformLimitSnapshot {
  const PlatformLimitSnapshot({
    required this.platform,
    required this.limit,
    required this.count,
    required this.tone,
  });

  final SocialPlatform platform;
  final int limit;
  final int count;
  final LimitTone tone;

  /// True when [count] is past [limit]. The limit itself stays amber.
  bool get isOverflow => tone == LimitTone.overflow;

  /// Usage ratio. Values above 1 mean the draft overflows the limit.
  double get fraction => limit <= 0 ? 0 : count / limit;
}

/// Where LinkedIn's mobile "see more" fold lands in the draft.
class LinkedInFoldSnapshot {
  const LinkedInFoldSnapshot({
    required this.foldThreshold,
    required this.foldOffset,
    required this.lineBreakOffsets,
    required this.foldLine,
    required this.nearestBreakAtOrBeforeFold,
    required this.hookLength,
    required this.hookExceedsFold,
    required this.pastFold,
  });

  /// Mobile cutoff used for the opening hook, in characters.
  final int foldThreshold;

  /// Character index of the cutoff. Equals the draft length when it fits.
  final int foldOffset;

  /// Indexes of `\n` in the normalized draft.
  final List<int> lineBreakOffsets;

  /// 1-based line that contains [foldOffset].
  final int foldLine;

  /// Last line-break index at or before the fold, if any.
  final int? nearestBreakAtOrBeforeFold;

  /// Length of the opening paragraph (before a blank line or slide rule).
  final int hookLength;

  /// True when the opening hook is longer than [foldThreshold].
  final bool hookExceedsFold;

  /// True when the full draft continues past the mobile cutoff.
  final bool pastFold;
}

/// Live word, read-time, and platform-limit metrics for a scratchpad draft.
///
/// Pure Dart. Counts the stored Markdown (newlines normalized) and never
/// rewrites that buffer into Unicode or HTML.
class PlatformMetrics {
  const PlatformMetrics({
    required this.wordCount,
    required this.readMinutes,
    required this.charCount,
    required this.linkedIn,
    required this.x,
    required this.threads,
    required this.fold,
  });

  static const int linkedInLimit = 3000;
  static const int xLimit = 280;
  static const int threadsLimit = 500;
  static const int linkedInFoldThreshold = 210;

  final int wordCount;
  final int readMinutes;
  final int charCount;
  final PlatformLimitSnapshot linkedIn;
  final PlatformLimitSnapshot x;
  final PlatformLimitSnapshot threads;
  final LinkedInFoldSnapshot fold;

  factory PlatformMetrics.analyze(String markdown) {
    final text = normalizeNewlines(markdown);
    final words = ScratchpadState.countWords(text);
    final count = text.length;
    return PlatformMetrics(
      wordCount: words,
      readMinutes: ScratchpadState.estimateReadMinutes(words),
      charCount: count,
      linkedIn: _limit(SocialPlatform.linkedIn, linkedInLimit, count),
      x: _limit(SocialPlatform.x, xLimit, count),
      threads: _limit(SocialPlatform.threads, threadsLimit, count),
      fold: _fold(text),
    );
  }

  PlatformLimitSnapshot limitFor(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.linkedIn:
        return linkedIn;
      case SocialPlatform.x:
        return x;
      case SocialPlatform.threads:
        return threads;
    }
  }

  /// Amber begins at 70% of [limit]. Red begins only after the limit.
  static LimitTone toneFor(int count, int limit) {
    if (limit <= 0) return LimitTone.safe;
    if (count > limit) return LimitTone.overflow;
    if (count * 10 >= limit * 7) return LimitTone.caution;
    return LimitTone.safe;
  }

  static String normalizeNewlines(String markdown) {
    return markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Opening hook: text before the first blank line or thematic break.
  static String openingHook(String normalized) {
    var end = normalized.length;
    final blank = RegExp(r'\n[ \t]*\n').firstMatch(normalized);
    if (blank != null && blank.start < end) end = blank.start;
    final rule = RegExp(
      r'^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$',
      multiLine: true,
    ).firstMatch(normalized);
    if (rule != null && rule.start < end) end = rule.start;
    return normalized.substring(0, end).trimRight();
  }

  static List<int> lineBreakOffsets(String normalized) {
    final offsets = <int>[];
    for (var i = 0; i < normalized.length; i++) {
      if (normalized.codeUnitAt(i) == 10) offsets.add(i);
    }
    return offsets;
  }

  static int lineNumberAt(String text, int offset) {
    final end = offset.clamp(0, text.length);
    var line = 1;
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 10) line++;
    }
    return line;
  }

  static int? nearestBreakAtOrBefore(List<int> offsets, int foldOffset) {
    int? nearest;
    for (final offset in offsets) {
      if (offset <= foldOffset) {
        nearest = offset;
      } else {
        break;
      }
    }
    return nearest;
  }

  static PlatformLimitSnapshot _limit(
    SocialPlatform platform,
    int limit,
    int count,
  ) {
    return PlatformLimitSnapshot(
      platform: platform,
      limit: limit,
      count: count,
      tone: toneFor(count, limit),
    );
  }

  static LinkedInFoldSnapshot _fold(String text) {
    final breaks = lineBreakOffsets(text);
    final pastFold = text.length > linkedInFoldThreshold;
    final foldOffset = pastFold ? linkedInFoldThreshold : text.length;
    final hook = openingHook(text);
    return LinkedInFoldSnapshot(
      foldThreshold: linkedInFoldThreshold,
      foldOffset: foldOffset,
      lineBreakOffsets: breaks,
      foldLine: lineNumberAt(text, foldOffset),
      nearestBreakAtOrBeforeFold: nearestBreakAtOrBefore(breaks, foldOffset),
      hookLength: hook.length,
      hookExceedsFold: hook.length > linkedInFoldThreshold,
      pastFold: pastFold,
    );
  }
}
