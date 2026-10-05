/// Visual job of one carousel card.
///
/// Auto-detection is positional. A caller may override the role of a slide;
/// those overrides travel with the slide when the deck is reordered.
enum SlideRole {
  cover('Cover'),
  body('Body'),
  cta('CTA');

  const SlideRole(this.label);

  /// Segmented-control label.
  final String label;
}

/// Positional defaults for [SlideRole] plus the cover/CTA copy the canvas paints.
abstract final class SlideRoles {
  /// Eyebrow on a cover card when the slide has no short topic heading.
  static const String coverEyebrow = 'SWIPE »';

  /// Action line on a CTA card.
  static const String ctaPrompt = 'Found this valuable? Repost & Follow';

  /// Default role for [index] in a deck of [totalSlides].
  ///
  /// A single slide is [SlideRole.body]. The first slide of a multi-slide
  /// deck is [SlideRole.cover]. The last slide is [SlideRole.cta] when the
  /// deck has at least two slides. Every slide between those is [SlideRole.body].
  static SlideRole detect({required int index, required int totalSlides}) {
    final total = totalSlides < 1 ? 1 : totalSlides;
    final safeIndex = index < 0 ? 0 : (index >= total ? total - 1 : index);
    if (total < 2) return SlideRole.body;
    if (safeIndex == 0) return SlideRole.cover;
    if (safeIndex == total - 1) return SlideRole.cta;
    return SlideRole.body;
  }

  /// Auto roles for a deck, in slide order.
  static List<SlideRole> forDeck(int totalSlides) {
    final total = totalSlides < 1 ? 1 : totalSlides;
    return [
      for (var i = 0; i < total; i++) detect(index: i, totalSlides: total),
    ];
  }

  /// Cover eyebrow: a short opening heading when one exists, otherwise
  /// [coverEyebrow].
  static String coverEyebrowFor(String markdown) {
    final lines = markdown.split(RegExp(r'\r\n|\n|\r'));
    for (final line in lines) {
      final match = RegExp(r'^#{1,3}[ \t]+(.+)$').firstMatch(line.trim());
      if (match == null) {
        if (line.trim().isEmpty) continue;
        break;
      }
      final topic = match.group(1)!.trim();
      if (topic.isNotEmpty && topic.length <= 28) return topic;
      break;
    }
    return coverEyebrow;
  }

  /// Resolved role: an explicit override wins, otherwise [detect].
  static SlideRole resolve({
    SlideRole? override,
    required int index,
    required int totalSlides,
  }) {
    return override ?? detect(index: index, totalSlides: totalSlides);
  }

  /// Destination index reported by [ReorderableListView.onReorderItem].
  ///
  /// [newIndex] is already the insert point after the dragged item is removed.
  static int reorderDestination(int oldIndex, int newIndex, int length) {
    if (length <= 1) return 0;
    if (oldIndex == newIndex) {
      if (oldIndex < 0) return 0;
      if (oldIndex >= length) return length - 1;
      return oldIndex;
    }
    if (newIndex < 0) return 0;
    if (newIndex >= length) return length - 1;
    return newIndex;
  }

  /// Moves override entries with their slides. Missing indexes stay automatic.
  static Map<int, SlideRole> remapAfterReorder(
    Map<int, SlideRole> overrides,
    int oldIndex,
    int newIndex,
    int length,
  ) {
    if (length <= 1 || oldIndex < 0 || oldIndex >= length) {
      return Map<int, SlideRole>.from(overrides);
    }
    final roles = [for (var i = 0; i < length; i++) overrides[i]];
    final target = reorderDestination(oldIndex, newIndex, length);
    final moved = roles.removeAt(oldIndex);
    roles.insert(target, moved);
    return _pack(roles);
  }

  /// Copies the override at [index] onto the duplicated slide and shifts the rest.
  static Map<int, SlideRole> remapAfterDuplicate(
    Map<int, SlideRole> overrides,
    int index,
    int length,
  ) {
    if (length < 1) return Map<int, SlideRole>.from(overrides);
    final safe = index < 0 ? 0 : (index >= length ? length - 1 : index);
    final roles = [for (var i = 0; i < length; i++) overrides[i]];
    roles.insert(safe + 1, roles[safe]);
    return _pack(roles);
  }

  /// Drops the override at [index] and closes the gap. A one-slide deck is unchanged.
  static Map<int, SlideRole> remapAfterDelete(
    Map<int, SlideRole> overrides,
    int index,
    int length,
  ) {
    if (length <= 1) return Map<int, SlideRole>.from(overrides);
    final safe = index < 0 ? 0 : (index >= length ? length - 1 : index);
    final roles = [for (var i = 0; i < length; i++) overrides[i]];
    roles.removeAt(safe);
    return _pack(roles);
  }

  static Map<int, SlideRole> _pack(List<SlideRole?> roles) {
    final packed = <int, SlideRole>{};
    for (var i = 0; i < roles.length; i++) {
      final role = roles[i];
      if (role != null) packed[i] = role;
    }
    return packed;
  }
}
