import 'package:penningpal/features/exporter/models/carousel_deck.dart';
import 'package:penningpal/features/exporter/models/carousel_markdown.dart';
import 'package:penningpal/features/exporter/models/slide_role.dart';
import 'package:penningpal/features/exporter/templates/card_theme_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlideRoles.detect', () {
    test('a single slide defaults to body', () {
      expect(SlideRoles.detect(index: 0, totalSlides: 1), SlideRole.body);
      expect(SlideRoles.forDeck(1), [SlideRole.body]);
    });

    test('two slides default to cover then cta', () {
      expect(
        SlideRoles.forDeck(2),
        [SlideRole.cover, SlideRole.cta],
      );
      expect(SlideRoles.detect(index: 0, totalSlides: 2), SlideRole.cover);
      expect(SlideRoles.detect(index: 1, totalSlides: 2), SlideRole.cta);
    });

    test('five slides default to cover, body, body, body, cta', () {
      expect(SlideRoles.forDeck(5), [
        SlideRole.cover,
        SlideRole.body,
        SlideRole.body,
        SlideRole.body,
        SlideRole.cta,
      ]);
    });

    test('an explicit override wins over the positional default', () {
      expect(
        SlideRoles.resolve(
          override: SlideRole.cta,
          index: 0,
          totalSlides: 5,
        ),
        SlideRole.cta,
      );
    });
  });

  group('CarouselMarkdown reorder', () {
    const source = 'Hook\n---\nInsight\n---\nClose';

    test('moving the last slide to the front rewrites --- sections in order', () {
      final next = CarouselMarkdown.reorder(source, 2, 0);
      expect(next, 'Close\n---\nHook\n---\nInsight');
      expect(CarouselDeck.fromMarkdown(next).slides, [
        'Close',
        'Hook',
        'Insight',
      ]);
    });

    test('dropping the first slide at the end rewrites --- sections in order', () {
      // onReorderItem reports the index after the dragged item is removed.
      final next = CarouselMarkdown.reorder(source, 0, 2);
      expect(next, 'Insight\n---\nClose\n---\nHook');
      expect(next.split(CarouselMarkdown.separator), [
        'Insight',
        'Close',
        'Hook',
      ]);
    });

    test('duplicate, delete, and add rewrite the same --- sections', () {
      final duplicated = CarouselMarkdown.duplicate(source, 1);
      expect(duplicated, 'Hook\n---\nInsight\n---\nInsight\n---\nClose');

      final deleted = CarouselMarkdown.delete(duplicated, 2);
      expect(deleted, 'Hook\n---\nInsight\n---\nClose');

      final added = CarouselMarkdown.addSlide(deleted);
      expect(
        added,
        'Hook\n---\nInsight\n---\nClose\n---\n${CarouselMarkdown.newSlideBody}',
      );
    });

    test('role overrides follow the slide they were set on', () {
      final moved = SlideRoles.remapAfterReorder(
        {0: SlideRole.cta, 2: SlideRole.cover},
        0,
        2,
        3,
      );
      expect(moved[1], SlideRole.cover);
      expect(moved[2], SlideRole.cta);
      expect(moved.containsKey(0), isFalse);
    });
  });

  group('CardLayout.fontScaleFor bounds', () {
    test('length buckets stay inside 0.75x and 1.15x', () {
      expect(CardLayout.fontScaleFor('x' * 0), CardLayout.hookScale);
      expect(CardLayout.fontScaleFor('x' * 119), 1.15);
      expect(CardLayout.fontScaleFor('x' * 120), CardLayout.baselineScale);
      expect(CardLayout.fontScaleFor('x' * 280), 1.0);
      expect(CardLayout.fontScaleFor('x' * 281), CardLayout.compactScale);
      expect(CardLayout.fontScaleFor('x' * 450), 0.85);
      expect(CardLayout.fontScaleFor('x' * 451), CardLayout.denseScale);
      expect(CardLayout.fontScaleFor('x' * 900), 0.75);

      for (var length = 0; length <= 800; length += 13) {
        final scale = CardLayout.fontScaleFor('x' * length);
        expect(scale, inInclusiveRange(0.75, 1.15));
      }
    });

    test('copy past 450 tightens line height and font size never drops under 12', () {
      expect(CardLayout.tightensLineHeight('x' * 450), isFalse);
      expect(CardLayout.tightensLineHeight('x' * 451), isTrue);
      expect(CardLayout.lineHeightFor('x' * 100), CardLayout.relaxedLineHeight);
      expect(CardLayout.lineHeightFor('x' * 451), CardLayout.tightLineHeight);
      expect(CardLayout.clampFontSize(8), CardLayout.minFontSize);
      expect(CardLayout.clampFontSize(12), 12);
      expect(CardLayout.clampFontSize(38), 38);
      expect(
        CardLayout.fontSizeFor('x' * 900, CardAspectRatio.square),
        greaterThanOrEqualTo(12),
      );
    });
  });
}
