/// Parsed scratchpad draft split into visual card slides.
///
/// Pure Dart: no Flutter imports. Horizontal rules in the raw markdown
/// (`---`, `***`, `___`) become slide boundaries; the original buffer is
/// never mutated.
class CarouselDeck {
  const CarouselDeck({required this.slides});

  /// Trimmed, non-empty slide bodies in display order.
  final List<String> slides;

  /// Markdown thematic break on its own line.
  ///
  /// Handles LF, CRLF, and CR. `---`, `***`, and `___` (three or more)
  /// are accepted. Horizontal `[ \t]*` is used instead of `\s*` so
  /// consecutive rules with blank lines between them are not swallowed
  /// into a single match.
  static final RegExp dividerPattern = RegExp(
    r'(?:\r\n|\n|\r|^)[ \t]*(?:-{3,}|_{3,}|\*{3,})[ \t]*(?:\r\n|\n|\r|$)',
  );

  int get totalSlides => slides.isEmpty ? 1 : slides.length;

  bool get isCarousel => slides.length > 1;

  /// Body shown for [index], clamped into range. Empty decks yield `''`.
  String slideAt(int index) {
    if (slides.isEmpty) return '';
    if (index <= 0) return slides.first;
    if (index >= slides.length) return slides.last;
    return slides[index];
  }

  /// Zero-based page index as `"1 / 5"`.
  static String formatPagination(int currentIndex, int totalSlides) {
    final total = totalSlides < 1 ? 1 : totalSlides;
    final page = currentIndex.clamp(0, total - 1) + 1;
    return '$page / $total';
  }

  /// Zero-based page index as `"Slide 1 of 5"`.
  static String formatSlideOf(int currentIndex, int totalSlides) {
    final total = totalSlides < 1 ? 1 : totalSlides;
    final page = currentIndex.clamp(0, total - 1) + 1;
    return 'Slide $page of $total';
  }

  String paginationLabel(int currentIndex) =>
      formatPagination(currentIndex, totalSlides);

  String slideOfLabel(int currentIndex) =>
      formatSlideOf(currentIndex, totalSlides);

  /// Splits [rawText] on markdown horizontal rules.
  ///
  /// Empty segments are discarded. When no divider is present (or every
  /// segment is blank), the trimmed draft is a single slide. The original
  /// buffer is never mutated.
  factory CarouselDeck.fromMarkdown(String rawText) {
    final parts = rawText.split(dividerPattern);
    final slides = <String>[
      for (final part in parts)
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (slides.isEmpty) {
      return CarouselDeck(slides: [rawText.trim()]);
    }
    return CarouselDeck(slides: List<String>.unmodifiable(slides));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CarouselDeck || other.slides.length != slides.length) {
      return false;
    }
    for (var i = 0; i < slides.length; i++) {
      if (other.slides[i] != slides[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slides);
}
