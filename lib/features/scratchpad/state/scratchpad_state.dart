import '../models/draft_item.dart';

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
    this.activeDraftId = '',
    this.title = DraftItem.untitled,
    this.status = DraftStatus.draft,
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
  final String activeDraftId;
  final String title;
  final DraftStatus status;

  /// Builds a full state snapshot from raw editor [content].
  factory ScratchpadState.fromContent(
    String content, {
    bool isSaving = false,
    String activeDraftId = '',
    String? title,
    DraftStatus status = DraftStatus.draft,
  }) {
    final words = countWords(content);
    return ScratchpadState(
      content: content,
      wordCount: words,
      charCount: content.length,
      estimatedReadMinutes: estimateReadMinutes(words),
      isSaving: isSaving,
      activeDraftId: activeDraftId,
      title: title ?? DraftItem.inferTitle(content),
      status: status,
    );
  }

  factory ScratchpadState.fromDraft(
    Draft draft, {
    bool isSaving = false,
  }) {
    return ScratchpadState.fromContent(
      draft.content,
      isSaving: isSaving,
      activeDraftId: draft.id,
      title: draft.title,
      status: draft.status,
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
    String? activeDraftId,
    String? title,
    DraftStatus? status,
  }) {
    return ScratchpadState(
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      charCount: charCount ?? this.charCount,
      estimatedReadMinutes: estimatedReadMinutes ?? this.estimatedReadMinutes,
      isSaving: isSaving ?? this.isSaving,
      activeDraftId: activeDraftId ?? this.activeDraftId,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}
