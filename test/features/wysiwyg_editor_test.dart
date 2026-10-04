import 'package:clean_canvas/core/persistence/draft_storage.dart';
import 'package:clean_canvas/features/exporter/models/carousel_deck.dart';
import 'package:clean_canvas/features/scratchpad/presentation/formatting_toolbar.dart';
import 'package:clean_canvas/features/scratchpad/presentation/quill_formatting.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_editor_styles.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/presentation/slide_break_embed.dart';
import 'package:clean_canvas/features/scratchpad/render/markdown_quill_bridge.dart';
import 'package:clean_canvas/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('markdown quill bridge', () {
    test('round-trips headings, emphasis, quotes, lists, and code', () {
      const source = '# Title\n'
          '## Sub\n'
          '**bold** and *italic* and ***both***\n'
          '> quoted\n'
          '- item\n'
          '`code`\n'
          'hello_world';

      final restored = deltaToMarkdown(
        Document.fromDelta(markdownToDelta(source)).toDelta(),
      );

      expect(restored, source);
      expect(restored, isNot(contains('__')));
    });

    test('slide dividers survive as --- and keep the carousel count', () {
      const source = '# Title\n\n**bold** text\n\n---\n\nSecond slide';
      final document = Document.fromDelta(markdownToDelta(source));
      final restored = deltaToMarkdown(document.toDelta());

      expect(restored, contains('---'));
      expect(restored, isNot(contains('***')));
      expect(CarouselDeck.fromMarkdown(restored).slides, hasLength(2));
      expect(CarouselDeck.fromMarkdown(source).slides, hasLength(2));
      expect(document.toPlainText(), isNot(contains('**')));
      expect(document.toPlainText(), isNot(contains('#')));
      expect(document.toPlainText(), isNot(contains('---')));
      expect(document.toPlainText(), contains('Title'));
      expect(document.toPlainText(), contains('bold'));
    });

    test('bold and italic toggles change attributes without raw asterisks', () {
      final controller = QuillController(
        document: Document.fromDelta(markdownToDelta('hello world')),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      addTearDown(controller.dispose);

      toggleQuillAttribute(controller, Attribute.bold);
      expect(controller.document.toPlainText(), isNot(contains('*')));
      expect(deltaToMarkdown(controller.document.toDelta()), '**hello** world');

      controller.updateSelection(
        const TextSelection(baseOffset: 6, extentOffset: 11),
        ChangeSource.local,
      );
      toggleQuillAttribute(controller, Attribute.italic);
      expect(controller.document.toPlainText(), isNot(contains('*')));
      expect(
        deltaToMarkdown(controller.document.toDelta()),
        '**hello** *world*',
      );
    });
  });

  group('WYSIWYG editor', () {
    testWidgets('loads markdown with headings, bold, and slide dividers', (
      tester,
    ) async {
      const source = '# Title\n\n**bold** text\n\n---\n\nSecond slide';
      final storage = DraftStorage();
      await storage.createDraft(initialContent: source);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final editor = tester.widget<QuillEditor>(
        find.byKey(const Key('scratchpad-field')),
      );
      final plain = editor.controller.document.toPlainText();
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('#')));
      expect(plain, isNot(contains('---')));
      expect(plain, contains('Title'));
      expect(plain, contains('bold'));

      final restored = deltaToMarkdown(editor.controller.document.toDelta());
      expect(restored, contains('---'));
      expect(CarouselDeck.fromMarkdown(restored).slides, hasLength(2));
      expect(find.textContaining('Slide Break'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('---'), findsNothing);
    });

    testWidgets('toolbar bold and italic do not insert asterisks', (
      tester,
    ) async {
      final storage = DraftStorage();
      await storage.createDraft(initialContent: 'hello world');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      final editor = tester.widget<QuillEditor>(
        find.byKey(const Key('scratchpad-field')),
      );
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('format-bold')));
      await tester.pump();

      editor.controller.updateSelection(
        const TextSelection(baseOffset: 6, extentOffset: 11),
        ChangeSource.local,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('format-italic')));
      await tester.pump();

      final plain = editor.controller.document.toPlainText();
      expect(plain, isNot(contains('*')));
      expect(plain, contains('hello world'));
      expect(
        deltaToMarkdown(editor.controller.document.toDelta()),
        '**hello** *world*',
      );
      expect(find.byKey(const Key('format-italic-active')), findsOneWidget);
    });

    testWidgets('editor styles match the PenningPal type scale', (tester) async {
      late DefaultStyles styles;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              styles = scratchpadEditorStyles(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(styles.h1!.style.fontSize, 26);
      expect(styles.h1!.style.fontWeight, FontWeight.w700);
      expect(styles.h1!.style.height, 1.15);
      expect(styles.h2!.style.fontSize, 21);
      expect(styles.h2!.style.fontWeight, FontWeight.w600);
      expect(styles.paragraph!.style.fontSize, 17);
      expect(styles.paragraph!.style.height, 1.5);
      expect(styles.quote!.style.fontStyle, FontStyle.italic);
      final border = styles.quote!.decoration!.border! as Border;
      expect(border.left.width, 3);
      expect(styles.lists!.horizontalSpacing.left, greaterThan(0));
    });

    testWidgets('editor paints the slide banner from an embed', (tester) async {
      final controller = QuillController(
        document: Document.fromDelta(
          markdownToDelta('First\n\n---\n\nSecond'),
        ),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      final focusNode = FocusNode();
      final scrollController = ScrollController();
      addTearDown(focusNode.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 480,
              child: Column(
                children: [
                  Expanded(
                    child: QuillEditor(
                      controller: controller,
                      focusNode: focusNode,
                      scrollController: scrollController,
                      config: const QuillEditorConfig(
                        embedBuilders: [SlideBreakEmbedBuilder()],
                      ),
                    ),
                  ),
                  FormattingToolbar(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('── Slide Break'), findsOneWidget);
      expect(find.textContaining('---'), findsNothing);
    });
  });
}
