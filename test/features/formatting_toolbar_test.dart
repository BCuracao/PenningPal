import 'package:clean_canvas/features/scratchpad/presentation/formatting_toolbar.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/presentation/styled_markdown_controller.dart';
import 'package:clean_canvas/features/scratchpad/state/markdown_formatter.dart';
import 'package:flutter/material.dart';
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
    Future<StyledMarkdownEditingController> pumpToolbar(
      WidgetTester tester, {
      required String text,
      required TextSelection selection,
    }) async {
      final controller = StyledMarkdownEditingController(text: text)
        ..selection = selection;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller),
                FormattingToolbar(controller: controller),
              ],
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('tapping Bold with selected text wraps the exact selection in **', (
      tester,
    ) async {
      final controller = await pumpToolbar(
        tester,
        text: 'hello world',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      await tester.tap(find.byKey(const Key('format-bold')));
      await tester.pump();

      expect(controller.text, '**hello** world');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
    });

    testWidgets('tapping + Slide inserts \\n\\n---\\n\\n at the cursor', (
      tester,
    ) async {
      final controller = await pumpToolbar(
        tester,
        text: 'hello',
        selection: const TextSelection.collapsed(offset: 5),
      );

      await tester.tap(find.byKey(const Key('format-slide')));
      await tester.pump();

      expect(controller.text, 'hello\n\n---\n\n');
      expect(
        controller.selection,
        TextSelection.collapsed(offset: 'hello\n\n---\n\n'.length),
      );
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

  group('StyledMarkdownEditingController', () {
    testWidgets('buildTextSpan bolds **bold** segments and dims markers', (
      tester,
    ) async {
      final controller = StyledMarkdownEditingController(text: '**bold**');
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF111111),
                ),
                withComposing: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(_plainText(span), '**bold**');
      final runs = _flatten(span);
      final content = runs.where((run) => run.text == 'bold');
      expect(content, isNotEmpty);
      expect(content.first.style?.fontWeight, FontWeight.bold);

      final markers = runs.where((run) => run.text == '**');
      expect(markers.length, 2);
      for (final marker in markers) {
        expect(marker.style?.fontWeight, isNot(FontWeight.bold));
        expect(marker.style?.color?.a, closeTo(0.35, 0.02));
      }
    });

    testWidgets('headings, quotes, code, and slide breaks receive distinct styles', (
      tester,
    ) async {
      const source = '# Title\n## Sub\n> quoted\n`code`\n---\n```\nfn()\n```';
      final controller = StyledMarkdownEditingController(text: source);
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF111111),
                ),
                withComposing: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(_plainText(span), source);
      final runs = _flatten(span);

      final title = runs.firstWhere((run) => run.text == 'Title');
      expect(title.style?.fontSize, MarkdownTextStyler.heading1Size);
      expect(title.style?.fontWeight, FontWeight.w700);

      final sub = runs.firstWhere((run) => run.text == 'Sub');
      expect(sub.style?.fontSize, MarkdownTextStyler.heading2Size);
      expect(sub.style?.fontWeight, FontWeight.w600);

      final quoted = runs.firstWhere((run) => run.text == 'quoted');
      expect(quoted.style?.fontStyle, FontStyle.italic);

      final code = runs.firstWhere((run) => run.text == 'code');
      expect(code.style?.fontFamily, 'monospace');

      final divider = runs.firstWhere((run) => run.text.contains('---'));
      expect(divider.style?.fontWeight, FontWeight.w600);
    });
  });
}

class _PaintedRun {
  const _PaintedRun(this.text, this.style);

  final String text;
  final TextStyle? style;
}

List<_PaintedRun> _flatten(TextSpan span, [TextStyle? inherited]) {
  final merged = inherited?.merge(span.style) ?? span.style;
  final out = <_PaintedRun>[];
  if (span.text != null && span.text!.isNotEmpty) {
    out.add(_PaintedRun(span.text!, merged));
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      out.addAll(_flatten(child, merged));
    }
  }
  return out;
}

String _plainText(TextSpan span) {
  final buffer = StringBuffer();
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text != null) buffer.write(node.text);
      node.children?.forEach(walk);
    }
  }

  walk(span);
  return buffer.toString();
}
