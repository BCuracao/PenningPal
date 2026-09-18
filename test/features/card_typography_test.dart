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
    test('punchy quotes under 120 characters scale up', () {
      expect(CardLayout.fontScaleFor('x' * 50), CardLayout.punchyScale);
      expect(CardLayout.fontScaleFor('x' * 119), CardLayout.punchyScale);
      expect(CardLayout.fontScaleFor('x' * 50), 1.25);
    });

    test('standard posts between 120 and 350 use 1.0x', () {
      expect(CardLayout.fontScaleFor('x' * 120), CardLayout.standardScale);
      expect(CardLayout.fontScaleFor('x' * 200), 1.0);
      expect(CardLayout.fontScaleFor('x' * 349), 1.0);
    });

    test('long-form copy between 350 and 650 scales down to 0.82x', () {
      expect(CardLayout.fontScaleFor('x' * 350), CardLayout.longFormScale);
      expect(CardLayout.fontScaleFor('x' * 500), 0.82);
      expect(CardLayout.fontScaleFor('x' * 650), 0.82);
    });

    test('very dense copy above 650 scales further to prevent clipping', () {
      expect(CardLayout.fontScaleFor('x' * 651), CardLayout.denseScale);
      expect(CardLayout.fontScaleFor('x' * 800), 0.7);
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
    Future<void> pumpCanvas(WidgetTester tester, {required String text}) async {
      tester.view.physicalSize = const Size(1200, 2000);
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
                aspectRatio: CardAspectRatio.square,
                theme: CardPresets.minimalClean,
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
