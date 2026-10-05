import 'carousel_deck.dart';
import 'slide_role.dart';

/// Structural edits to a carousel draft.
///
/// Slides are read with [CarouselDeck.fromMarkdown] so `---`, `***`, and
/// `___` breaks all participate, then written back joined on [separator].
/// The input string is never mutated.
abstract final class CarouselMarkdown {
  /// Canonical thematic break written back into the scratchpad buffer.
  static const String separator = '\n---\n';

  /// Placeholder body for a newly inserted slide. Empty segments are dropped
  /// by the deck parser, so a new page has to contain visible text.
  static const String newSlideBody = 'New slide';

  static List<String> slidesOf(String markdown) {
    final deck = CarouselDeck.fromMarkdown(markdown);
    if (deck.slides.isEmpty) return const [''];
    return List<String>.from(deck.slides);
  }

  static String join(List<String> slides) {
    if (slides.isEmpty) return '';
    return slides.join(separator);
  }

  /// Moves the slide at [oldIndex] to [newIndex].
  ///
  /// [newIndex] is the insert index from [ReorderableListView.onReorderItem],
  /// already adjusted for the removed item.
  static String reorder(String markdown, int oldIndex, int newIndex) {
    final slides = slidesOf(markdown);
    if (slides.length < 2 || oldIndex < 0 || oldIndex >= slides.length) {
      return join(slides);
    }
    final target = SlideRoles.reorderDestination(
      oldIndex,
      newIndex,
      slides.length,
    );
    if (target == oldIndex) return join(slides);
    final moved = slides.removeAt(oldIndex);
    slides.insert(target, moved);
    return join(slides);
  }

  /// Inserts a copy of the slide at [index] immediately after it.
  static String duplicate(String markdown, int index) {
    final slides = slidesOf(markdown);
    if (slides.isEmpty) return newSlideBody;
    final safe = index < 0 ? 0 : (index >= slides.length ? slides.length - 1 : index);
    slides.insert(safe + 1, slides[safe]);
    return join(slides);
  }

  /// Removes the slide at [index]. The last remaining slide is kept.
  static String delete(String markdown, int index) {
    final slides = slidesOf(markdown);
    if (slides.length <= 1) return join(slides);
    final safe = index < 0 ? 0 : (index >= slides.length ? slides.length - 1 : index);
    slides.removeAt(safe);
    return join(slides);
  }

  /// Appends a new slide page.
  static String addSlide(String markdown) {
    final slides = slidesOf(markdown);
    if (slides.length == 1 && slides.single.trim().isEmpty) {
      return newSlideBody;
    }
    slides.add(newSlideBody);
    return join(slides);
  }
}
