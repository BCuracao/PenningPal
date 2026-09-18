import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/syntax_card_block.dart';
import 'package:clean_canvas/features/exporter/render/code_block_parser.dart';
import 'package:clean_canvas/features/exporter/templates/card_theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CodeBlockParser', () {
    const parser = CodeBlockParser();

    test('extracts a fenced dart block with its language tag', () {
      const raw = '''
```dart
void main() {
  print('hi');
}
```
''';
      final parsed = parser.parse(raw);

      expect(parsed.hasCode, isTrue);
      expect(parsed.isCodeOnly, isTrue);
      expect(parsed.segments, hasLength(1));
      final code = parsed.segments.single as CodeBlockSegment;
      expect(code.language, 'dart');
      expect(code.isHighlighted, isTrue);
      expect(code.highlightLanguage, 'dart');
      expect(code.code, contains("print('hi')"));
      expect(code.code, isNot(contains('```')));
    });

    test('extracts a fence with no language as plain monospace', () {
      const raw = '```\nSELECT 1;\n```';
      final parsed = parser.parse(raw);
      final code = parsed.segments.single as CodeBlockSegment;

      expect(code.language, isNull);
      expect(code.isHighlighted, isFalse);
      expect(code.highlightLanguage, isNull);
      expect(code.code, 'SELECT 1;');
    });

    test('unrecognized languages keep the tag but skip highlighting', () {
      const raw = '```brainfuck\n++++\n```';
      final parsed = parser.parse(raw);
      final code = parsed.segments.single as CodeBlockSegment;

      expect(code.language, 'brainfuck');
      expect(code.isHighlighted, isFalse);
      expect(CodeBlockParser.resolveLanguage('brainfuck'), isNull);
      expect(CodeBlockParser.resolveLanguage(null), isNull);
      expect(CodeBlockParser.resolveLanguage(''), isNull);
    });

    test('maps common aliases onto highlight.js ids', () {
      expect(CodeBlockParser.resolveLanguage('JS'), 'javascript');
      expect(CodeBlockParser.resolveLanguage('ts'), 'typescript');
      expect(CodeBlockParser.resolveLanguage('py'), 'python');
      expect(CodeBlockParser.resolveLanguage('rs'), 'rust');
      expect(CodeBlockParser.resolveLanguage('c#'), 'cs');
    });

    test('splits mixed prose + code + prose without dropping text', () {
      const raw = '''
Ship this snippet:

```python
def greet(name):
    return f"hi {name}"
```

Then post the screenshot.
''';
      final parsed = parser.parse(raw);

      expect(parsed.segments, hasLength(3));
      expect(parsed.hasCode, isTrue);
      expect(parsed.isCodeOnly, isFalse);

      final before = parsed.segments[0] as ProseSegment;
      final code = parsed.segments[1] as CodeBlockSegment;
      final after = parsed.segments[2] as ProseSegment;

      expect(before.text, 'Ship this snippet:');
      expect(code.language, 'python');
      expect(code.code, contains('def greet'));
      expect(after.text, 'Then post the screenshot.');
    });

    test('parses multiple fenced blocks in order', () {
      const raw = '''
```js
console.log(1)
```

note

```swift
print("two")
```
''';
      final parsed = parser.parse(raw);
      expect(parsed.segments, hasLength(3));
      expect((parsed.segments[0] as CodeBlockSegment).language, 'js');
      expect((parsed.segments[1] as ProseSegment).text, 'note');
      expect((parsed.segments[2] as CodeBlockSegment).language, 'swift');
    });

    test('unclosed fences consume the remainder as code', () {
      const raw = 'intro\n```rust\nfn main() {}';
      final parsed = parser.parse(raw);
      expect(parsed.segments, hasLength(2));
      expect((parsed.segments[0] as ProseSegment).text, 'intro');
      expect((parsed.segments[1] as CodeBlockSegment).code, 'fn main() {}');
    });

    test('does not treat inline backticks as a fence', () {
      const raw = 'Use `print()` and ```ticks``` in prose.';
      final parsed = parser.parse(raw);
      expect(parsed.hasCode, isFalse);
      expect((parsed.segments.single as ProseSegment).text, raw);
    });

    test('never mutates the source markdown buffer', () {
      var source = 'before\n```json\n{"a": 1}\n```\nafter';
      final parsed = parser.parse(source);
      expect(source, 'before\n```json\n{"a": 1}\n```\nafter');
      expect(parsed.hasCode, isTrue);
    });

    test('returns an empty parse for blank input', () {
      expect(parser.parse('').isEmpty, isTrue);
      expect(parser.parse('   \n').hasCode, isFalse);
    });
  });

  group('SyntaxCardBlock scaling', () {
    test('long lines produce a smaller font than short snippets', () {
      const short = 'print(1)';
      final long = 'print("${'x' * 160}");';
      expect(
        SyntaxCardBlock.fontSizeFor(code: short, maxWidth: 800),
        greaterThan(
          SyntaxCardBlock.fontSizeFor(code: long, maxWidth: 800),
        ),
      );
    });
  });

  group('CardCanvas code highlighting', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      required String text,
      CardAspectRatio aspect = CardAspectRatio.square,
      CardThemeConfig theme = CardPresets.minimalClean,
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
                theme: theme,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('embeds SyntaxCardBlock between surrounding prose', (
      tester,
    ) async {
      const raw = '''
Before the snippet

```dart
void main() {}
```

After the snippet
''';
      await pumpCanvas(tester, text: raw);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('syntax-card-block')), findsOneWidget);
      expect(find.text('Before the snippet'), findsOneWidget);
      expect(find.text('After the snippet'), findsOneWidget);
      expect(find.textContaining('void main()'), findsOneWidget);
    });

    testWidgets('long snippets do not overflow square or story canvases', (
      tester,
    ) async {
      final longLine =
          'final payload = "${List.filled(120, 'token').join('-')}";';
      final manyLines = List.generate(
        36,
        (i) => 'print("line-$i-of-a-dense-snippet");',
      ).join('\n');
      final raw = '''
Dense example

```python
$longLine
$manyLines
```
''';

      await pumpCanvas(tester, text: raw);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('syntax-card-block')), findsOneWidget);

      await pumpCanvas(
        tester,
        text: raw,
        aspect: CardAspectRatio.story,
        theme: CardPresets.devTerminal,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('syntax-card-block')), findsOneWidget);
      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
    });

    testWidgets('Minimal uses a light code surface', (tester) async {
      await pumpCanvas(
        tester,
        text: '```js\nconsole.log(1)\n```',
      );

      final block = tester.widget<SyntaxCardBlock>(
        find.byType(SyntaxCardBlock),
      );
      expect(block.palette.background, const Color(0xFFF1F5F9));
    });

    testWidgets('Dev Terminal uses a dark code surface and window chrome', (
      tester,
    ) async {
      await pumpCanvas(
        tester,
        text: '```dart\nfinal n = 1;\n```',
        theme: CardPresets.devTerminal,
      );

      final block = tester.widget<SyntaxCardBlock>(
        find.byType(SyntaxCardBlock),
      );
      expect(block.palette.background, const Color(0xFF0D1117));
      expect(block.showWindowChrome, isTrue);
      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
    });
  });
}
