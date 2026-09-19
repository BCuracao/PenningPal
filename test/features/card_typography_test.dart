import 'package:clean_canvas/features/exporter/models/carousel_deck.dart';
import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/markdown_card_content.dart';
import 'package:clean_canvas/features/exporter/templates/card_theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Representative 3-slide draft using mixed newline styles and dividers.
const threeSlideDraft =
    '# The Hook\r\nA punchy opening for the carousel.\r\n\r\n---\r\n\r\n'
    '## The Insight\n'
    '**Bold claim** with a supporting line.\n\n'
    '***\n\n'
    '> Closing quote on the last slide.';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CarouselDeck hardened splitter', () {
    test('the 3-slide mixed-newline draft splits into exactly 3 slides', () {
      final deck = CarouselDeck.fromMarkdown(threeSlideDraft);
      expect(deck.slides, hasLength(3));
      expect(deck.totalSlides, 3);
      expect(deck.isCarousel, isTrue);
      expect(deck.slides[0], contains('The Hook'));
      expect(deck.slides[1], contains('The Insight'));
      expect(deck.slides[2], contains('Closing quote'));
    });

    test('splits CRLF, LF, and mixed --- / *** / ___ dividers', () {
      const raw = 'One\r\n---\r\nTwo\n***\nThree\r\n___\r\nFour';
      expect(CarouselDeck.fromMarkdown(raw).slides, ['One', 'Two', 'Three', 'Four']);
    });
  });

  group('CardLayout.fontScaleFor', () {
    test('punchy quotes under 140 characters scale up 1.35x', () {
      expect(CardLayout.fontScaleFor('x' * 50), CardLayout.punchyScale);
      expect(CardLayout.fontScaleFor('x' * 139), CardLayout.punchyScale);
      expect(CardLayout.fontScaleFor('x' * 50), 1.35);
    });

    test('standard posts between 140 and 350 use 1.1x', () {
      expect(CardLayout.fontScaleFor('x' * 140), CardLayout.standardScale);
      expect(CardLayout.fontScaleFor('x' * 200), 1.1);
      expect(CardLayout.fontScaleFor('x' * 349), 1.1);
    });

    test('long-form copy between 350 and 700 scales to 0.95x', () {
      expect(CardLayout.fontScaleFor('x' * 350), CardLayout.longFormScale);
      expect(CardLayout.fontScaleFor('x' * 500), 0.95);
      expect(CardLayout.fontScaleFor('x' * 700), 0.95);
    });

    test('dense copy above 700 stays at the 0.82x floor', () {
      expect(CardLayout.fontScaleFor('x' * 701), CardLayout.denseScale);
      expect(CardLayout.fontScaleFor('x' * 800), 0.82);
      expect(CardLayout.fontScaleFor('x' * 2000), greaterThanOrEqualTo(0.82));
    });
  });

  group('CardMarkdownStyles canvas type scale', () {
    test('uses 1080px-proportional sizes, not mobile point sizes', () {
      final styles = CardMarkdownStyles.from(
        theme: CardPresets.minimalClean,
        fontScale: 1.0,
        fontFamily: CardThemeConfig.fontInter,
      );
      expect(styles.h1.fontSize, 78);
      expect(styles.h1.fontWeight, FontWeight.w800);
      expect(styles.h1.height, 1.2);
      expect(styles.h1.letterSpacing, -0.8);

      expect(styles.h2.fontSize, 60);
      expect(styles.h2.fontWeight, FontWeight.w700);
      expect(styles.h2.height, 1.25);
      expect(styles.h2.letterSpacing, -0.5);

      expect(styles.h3.fontSize, 48);
      expect(styles.h3.fontWeight, FontWeight.w600);
      expect(styles.h3.height, 1.3);

      expect(styles.paragraph.fontSize, 38);
      expect(styles.paragraph.fontWeight, FontWeight.w400);
      expect(styles.paragraph.height, 1.55);

      expect(styles.strong.fontWeight, FontWeight.w700);
      expect(styles.emphasis.fontStyle, FontStyle.italic);

      expect(styles.quote.fontSize, 42);
      expect(styles.quote.fontStyle, FontStyle.italic);

      expect(styles.listItem.fontSize, 38);
      expect(styles.inlineCode.fontSize, 32);
      expect(styles.inlineCode.height, 1.4);

      expect(CardMarkdownStyles.quoteBorderWidth, 6);
      expect(CardMarkdownStyles.quotePadding, 28);
      expect(CardMarkdownStyles.listItemGap, 18);
    });
  });

  group('MarkdownCardContent', () {
    Future<void> pumpMarkdown(
      WidgetTester tester, {
      required String content,
      double fontScale = 1.0,
    }) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 952,
              child: MarkdownCardContent(
                content: content,
                theme: CardPresets.minimalClean,
                fontScale: fontScale,
                fontFamily: CardThemeConfig.fontInter,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('strips #, **, and > from the rendered widget tree', (
      tester,
    ) async {
      const raw = '# Header\n**bold text**\n> quote';
      await pumpMarkdown(tester, content: raw);

      expect(find.byKey(const Key('markdown-card-content')), findsOneWidget);
      expect(find.textContaining('Header'), findsWidgets);
      expect(find.textContaining('bold text'), findsWidgets);
      expect(find.textContaining('quote'), findsWidgets);

      final visible = _plainTextUnder(
        tester,
        find.byKey(const Key('markdown-card-content')),
      );
      expect(visible, isNot(contains('#')));
      expect(visible, isNot(contains('**')));
      expect(visible, isNot(contains('>')));
      expect(visible, contains('Header'));
      expect(visible, contains('bold text'));
      expect(visible, contains('quote'));
    });

    testWidgets('renders italics, lists, and inline code without markers', (
      tester,
    ) async {
      const raw = '*italic*\n\n- first\n- second\n\nUse `code` here.';
      await pumpMarkdown(tester, content: raw);

      final visible = _plainTextUnder(
        tester,
        find.byKey(const Key('markdown-card-content')),
      );
      expect(visible, contains('italic'));
      expect(visible, contains('first'));
      expect(visible, contains('second'));
      expect(visible, contains('•'));
      expect(visible, contains('code'));
      expect(visible, isNot(contains('*italic*')));
      expect(visible, isNot(contains('- first')));
      expect(visible, isNot(contains('`code`')));
    });
  });

  group('CardCanvas markdown + scaling', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      required String text,
      CardAspectRatio aspect = CardAspectRatio.square,
      String? author,
      String? authorHandle,
    }) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FittedBox(
              fit: BoxFit.contain,
              child: CardCanvas(
                canvasKey: GlobalKey(),
                text: text,
                aspectRatio: aspect,
                theme: CardPresets.minimalClean,
                author: author,
                authorHandle: authorHandle,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('canvas does not paint raw markdown tokens', (tester) async {
      await pumpCanvas(tester, text: '# Header\n**bold text**\n> quote');

      expect(tester.takeException(), isNull);
      expect(find.byType(MarkdownCardContent), findsOneWidget);

      final visible = _plainTextUnder(
        tester,
        find.byKey(const Key('card-body-text')),
      );
      expect(visible, isNot(contains('#')));
      expect(visible, isNot(contains('**')));
      expect(visible, isNot(contains('>')));
    });

    testWidgets('long copy still fits the 1080 square without overflow', (
      tester,
    ) async {
      final long = List.generate(
        24,
        (i) => 'Paragraph $i with enough words to fill a long-form card.',
      ).join('\n\n');
      await pumpCanvas(tester, text: long);
      expect(tester.takeException(), isNull);
      expect(CardLayout.fontScaleFor(long), lessThan(1.0));
    });

    testWidgets('author name, handle, and watermark use canvas type sizes', (
      tester,
    ) async {
      await pumpCanvas(
        tester,
        text: 'A short quote for the card.',
        author: 'Ada Lovelace',
        authorHandle: '@ada',
      );

      final name = tester.widget<Text>(find.text('Ada Lovelace'));
      expect(name.style?.fontSize, CardLayout.authorNameSize);
      expect(name.style?.fontWeight, FontWeight.w700);

      final handle = tester.widget<Text>(find.text('@ada'));
      expect(handle.style?.fontSize, CardLayout.authorHandleSize);

      final watermark = tester.widget<Text>(
        find.text(CardLayout.watermarkLabel),
      );
      expect(watermark.style?.fontSize, CardLayout.watermarkSize);
    });

    testWidgets('story layout vertically centers body between header and footer',
        (tester) async {
      await pumpCanvas(
        tester,
        text: 'Stay hungry.',
        aspect: CardAspectRatio.story,
      );

      expect(tester.takeException(), isNull);
      final brand = tester.getRect(find.byKey(const Key('card-brand-slot')));
      final body = tester.getRect(find.byKey(const Key('card-body-text')));
      final watermark = tester.getRect(find.byKey(const Key('card-watermark')));

      expect(body.top, greaterThan(brand.bottom));
      expect(body.bottom, lessThan(watermark.top));

      final spaceAbove = body.top - brand.bottom;
      final spaceBelow = watermark.top - body.bottom;
      expect(spaceAbove, greaterThan(120));
      expect((spaceAbove - spaceBelow).abs(), lessThan(80));
    });

    testWidgets('FittedBox preview keeps the 1080 canvas layout size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: FittedBox(
                  key: const Key('card-preview'),
                  fit: BoxFit.contain,
                  child: CardCanvas(
                    canvasKey: GlobalKey(),
                    text: '# Headline\nBody copy on the canvas.',
                    aspectRatio: CardAspectRatio.square,
                    theme: CardPresets.minimalClean,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('card-canvas'))),
        const Size(1080, 1080),
      );
      final preview = tester.getSize(find.byKey(const Key('card-preview')));
      expect(preview.width, lessThanOrEqualTo(360));
      expect(preview.height, lessThanOrEqualTo(360));
    });
  });
}

String _plainTextUnder(WidgetTester tester, Finder root) {
  final buffer = StringBuffer();

  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      buffer.write(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    } else if (widget is RichText) {
      buffer.write(widget.text.toPlainText());
    }
    element.visitChildren(visit);
  }

  for (final element in root.evaluate()) {
    visit(element);
  }
  return buffer.toString();
}
