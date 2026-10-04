import 'package:clean_canvas/features/scratchpad/presentation/formatting_toolbar.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/render/markdown_quill_bridge.dart';
import 'package:clean_canvas/features/scratchpad/state/markdown_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const formatter = MarkdownFormatter();

  group('MarkdownFormatter', () {
    test('Bold wraps the exact selection in **', () {
      final result = formatter.toggleBold('hello world', 0, 5);
      expect(result.text, '**hello** world');
      expect(result.selectionStart, 2);
      expect(result.selectionEnd, 7);
    });

    test('Bold inserts a placeholder at the caret', () {
      final result = formatter.toggleBold('ab', 1, 1);
      expect(result.text, 'a**bold**b');
      expect(result.selectionStart, 3);
      expect(result.selectionEnd, 7);
    });

    test('Bold unwraps an existing ** pair', () {
      final result = formatter.toggleBold('**hello** world', 2, 7);
      expect(result.text, 'hello world');
      expect(result.selectionStart, 0);
      expect(result.selectionEnd, 5);
    });

    test('Italic wraps the selection in *', () {
      final result = formatter.toggleItalic('hello', 0, 5);
      expect(result.text, '*hello*');
    });

    test('Italic does not unwrap **bold** as a single star', () {
      final result = formatter.toggleItalic('**hello**', 2, 7);
      expect(result.text, '***hello***');
    });

    test('Heading cycles #, ##, ###, then plain', () {
      var result = formatter.cycleHeading('Hello', 0, 0);
      expect(result.text, '# Hello');
      result = formatter.cycleHeading(result.text, result.selectionStart, result.selectionEnd);
      expect(result.text, '## Hello');
      result = formatter.cycleHeading(result.text, result.selectionStart, result.selectionEnd);
      expect(result.text, '### Hello');
      result = formatter.cycleHeading(result.text, result.selectionStart, result.selectionEnd);
      expect(result.text, 'Hello');
    });

    test('Bullet toggles - at the start of the line', () {
      var result = formatter.toggleBullet('item', 2, 2);
      expect(result.text, '- item');
      result = formatter.toggleBullet(result.text, result.selectionStart, result.selectionEnd);
      expect(result.text, 'item');
    });

    test('Quote toggles > at the start of the line', () {
      var result = formatter.toggleQuote('note', 0, 4);
      expect(result.text, '> note');
      result = formatter.toggleQuote(result.text, result.selectionStart, result.selectionEnd);
      expect(result.text, 'note');
    });

    test('Code wraps a single-line selection in backticks', () {
      final result = formatter.toggleCode('print', 0, 5);
      expect(result.text, '`print`');
    });

    test('Code wraps a multi-line selection in a fenced block', () {
      final result = formatter.toggleCode('one\ntwo', 0, 7);
      expect(result.text, '```\none\ntwo\n```');
      expect(result.selectionStart, 4);
      expect(result.selectionEnd, 11);
    });

    test('+ Slide inserts \\n\\n---\\n\\n at the cursor', () {
      final result = formatter.insertSlideBreak('hello', 5, 5);
      expect(result.text, 'hello\n\n---\n\n');
      expect(result.selectionStart, 'hello\n\n---\n\n'.length);
      expect(result.selectionEnd, result.selectionStart);
    });
  });

  group('FormattingToolbar', () {
    Future<QuillController> pumpToolbar(
      WidgetTester tester, {
      required String markdown,
      required TextSelection selection,
    }) async {
      final controller = QuillController(
        document: Document.fromDelta(markdownToDelta(markdown)),
        selection: selection,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattingToolbar(controller: controller),
          ),
        ),
      );
      return controller;
    }

    testWidgets('tapping Bold formats the selection without inserting asterisks', (
      tester,
    ) async {
      final controller = await pumpToolbar(
        tester,
        markdown: 'hello world',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      await tester.tap(find.byKey(const Key('format-bold')));
      await tester.pump();

      expect(controller.document.toPlainText(), isNot(contains('*')));
      expect(controller.document.toPlainText(), contains('hello world'));
      expect(deltaToMarkdown(controller.document.toDelta()), '**hello** world');
      expect(find.byKey(const Key('format-bold-active')), findsOneWidget);
    });

    testWidgets('tapping + Slide inserts a divider that serializes as ---', (
      tester,
    ) async {
      final controller = await pumpToolbar(
        tester,
        markdown: 'Hello\nWorld',
        selection: const TextSelection.collapsed(offset: 6),
      );

      await tester.tap(find.byKey(const Key('format-slide')));
      await tester.pump();

      final markdown = deltaToMarkdown(controller.document.toDelta());
      expect(markdown, contains('---'));
      expect(controller.document.toPlainText(), isNot(contains('---')));
      expect(markdown.split('---').length, 2);
    });

    testWidgets('ScratchpadScreen hosts the formatting accessory', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ScratchpadScreen()),
        ),
      );

      expect(find.byKey(const Key('formatting-toolbar')), findsOneWidget);
      expect(find.byKey(const Key('format-bold')), findsOneWidget);
      expect(find.byKey(const Key('format-slide')), findsOneWidget);
    });
  });
}
