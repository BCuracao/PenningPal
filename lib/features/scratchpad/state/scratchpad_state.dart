/// Immutable snapshot of the scratchpad editor.
///
/// Stats are derived from [content] with no Flutter or I/O dependencies so
/// word/character/read-time logic can be unit-tested in isolation.
class ScratchpadState {
  const ScratchpadState({
    required this.content,
    required this.wordCount,
    required this.charCount,
    required this.estimatedReadMinutes,
    this.isSaving = false,
  });

  static const int wordsPerMinute = 200;

  static const ScratchpadState empty = ScratchpadState(
    content: '',
    wordCount: 0,
    charCount: 0,
    estimatedReadMinutes: 0,
  );

  /// Whitespace and punctuation separators for word tokens.
  static final RegExp _wordSeparator = RegExp(r'[\s\p{P}]+', unicode: true);

  final String content;
  final int wordCount;
  final int charCount;
  final int estimatedReadMinutes;
  final bool isSaving;

  /// Builds a full state snapshot from raw editor [content].
  factory ScratchpadState.fromContent(
    String content, {
    bool isSaving = false,
  }) {
    final words = countWords(content);
    return ScratchpadState(
      content: content,
      wordCount: words,
      charCount: content.length,
      estimatedReadMinutes: estimateReadMinutes(words),
      isSaving: isSaving,
    );
  }

  /// Counts tokens split on whitespace and punctuation.
  ///
  /// Empty strings and whitespace-only input yield `0`.
  static int countWords(String text) {
    if (text.isEmpty) return 0;
    return text.split(_wordSeparator).where((token) => token.isNotEmpty).length;
  }

  /// Ceil-divides [wordCount] by [wordsPerMinute]. Empty drafts are `0`.
  static int estimateReadMinutes(int wordCount) {
    if (wordCount <= 0) return 0;
    return (wordCount / wordsPerMinute).ceil();
  }

  ScratchpadState copyWith({
    String? content,
    int? wordCount,
    int? charCount,
    int? estimatedReadMinutes,
    bool? isSaving,
  }) {
    return ScratchpadState(
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      charCount: charCount ?? this.charCount,
      estimatedReadMinutes: estimatedReadMinutes ?? this.estimatedReadMinutes,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
