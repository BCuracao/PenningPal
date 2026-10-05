import 'package:penningpal/core/persistence/draft_storage.dart';
import 'package:penningpal/features/exporter/models/carousel_deck.dart';
import 'package:penningpal/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:penningpal/features/scratchpad/presentation/widgets/linkedin_fold_indicator.dart';
import 'package:penningpal/features/scratchpad/presentation/widgets/platform_counter_hud.dart';
import 'package:penningpal/features/scratchpad/render/markdown_quill_bridge.dart';
import 'package:penningpal/features/scratchpad/state/framework_templates.dart';
import 'package:penningpal/features/scratchpad/state/platform_metrics.dart';
import 'package:penningpal/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PlatformMetrics', () {
    test('counts words and ceil-divides reading time at 200 wpm', () {
      expect(PlatformMetrics.analyze('').wordCount, 0);
      expect(PlatformMetrics.analyze('').readMinutes, 0);

      final four = PlatformMetrics.analyze('one two three four');
      expect(four.wordCount, 4);
      expect(four.readMinutes, 1);

      final long = PlatformMetrics.analyze(List.filled(400, 'word').join(' '));
      expect(long.wordCount, 400);
      expect(long.readMinutes, 2);
    });

    test('flags overflow only after each platform limit', () {
      expect(PlatformMetrics.toneFor(195, 280), LimitTone.safe);
      expect(PlatformMetrics.toneFor(196, 280), LimitTone.caution);
      expect(PlatformMetrics.toneFor(280, 280), LimitTone.caution);
      expect(PlatformMetrics.toneFor(281, 280), LimitTone.overflow);

      final atX = PlatformMetrics.analyze('x' * 280);
      expect(atX.x.count, 280);
      expect(atX.x.isOverflow, isFalse);
      expect(atX.x.tone, LimitTone.caution);
      expect(atX.threads.isOverflow, isFalse);
      expect(atX.linkedIn.isOverflow, isFalse);

      final overX = PlatformMetrics.analyze('x' * 281);
      expect(overX.x.isOverflow, isTrue);
      expect(overX.x.tone, LimitTone.overflow);
      expect(overX.threads.tone, LimitTone.safe);

      expect(PlatformMetrics.analyze('x' * 500).threads.isOverflow, isFalse);
      expect(PlatformMetrics.analyze('x' * 501).threads.isOverflow, isTrue);
      expect(PlatformMetrics.analyze('x' * 3000).linkedIn.isOverflow, isFalse);
      expect(PlatformMetrics.analyze('x' * 3001).linkedIn.isOverflow, isTrue);
      expect(
        PlatformMetrics.analyze('x' * 3001).linkedIn.fraction,
        greaterThan(1),
      );
    });

    test('warns when the opening hook passes the 210-character fold', () {
      final fitted = PlatformMetrics.analyze('a' * 210);
      expect(fitted.fold.hookExceedsFold, isFalse);
      expect(fitted.fold.pastFold, isFalse);
      expect(fitted.fold.foldOffset, 210);
      expect(fitted.fold.foldLine, 1);

      final over = PlatformMetrics.analyze('a' * 211);
      expect(over.fold.hookExceedsFold, isTrue);
      expect(over.fold.pastFold, isTrue);
      expect(over.fold.foldOffset, PlatformMetrics.linkedInFoldThreshold);
      expect(over.fold.hookLength, 211);
    });

    test('tracks line-break offsets and the line that holds the fold', () {
      final text = '${'a' * 50}\n${'b' * 200}';
      final fold = PlatformMetrics.analyze(text).fold;

      expect(fold.lineBreakOffsets, [50]);
      expect(fold.foldOffset, 210);
      expect(fold.foldLine, 2);
      expect(fold.nearestBreakAtOrBeforeFold, 50);
      expect(fold.pastFold, isTrue);
    });

    test('opening hook stops at a blank line and normalizes CRLF', () {
      final folded = PlatformMetrics.analyze('${'a' * 50}\n\n${'b' * 300}');
      expect(folded.fold.hookLength, 50);
      expect(folded.fold.hookExceedsFold, isFalse);
      expect(folded.fold.pastFold, isTrue);

      final crlf = PlatformMetrics.analyze('ab\r\ncd');
      expect(crlf.charCount, 5);
      expect(crlf.fold.lineBreakOffsets, [2]);
      expect(crlf.fold.foldLine, 2);
    });
  });

  group('FrameworkTemplates', () {
    test('each framework keeps a carousel slide break', () {
      for (final template in FrameworkTemplates.all) {
        expect(template.markdown, contains('\n---\n'));
        final deck = CarouselDeck.fromMarkdown(template.markdown);
        expect(deck.isCarousel, isTrue, reason: template.title);
        expect(deck.slides, hasLength(2), reason: template.title);
      }
    });

    test('append keeps existing slide breaks and the template break', () {
      const current = 'Intro\n\n---\n\nSecond';
      final applied = FrameworkTemplates.apply(
        current: current,
        template: FrameworkTemplates.contrarianHook,
        mode: TemplateInsertMode.append,
      );

      expect(applied, startsWith('Intro'));
      expect(applied, contains(FrameworkTemplates.contrarianHook.markdown));
      expect(CarouselDeck.fromMarkdown(applied).slides, hasLength(3));

      final restored = deltaToMarkdown(
        Document.fromDelta(markdownToDelta(applied)).toDelta(),
      );
      expect(restored, contains('---'));
      expect(
        CarouselDeck.fromMarkdown(restored).slides,
        hasLength(CarouselDeck.fromMarkdown(applied).slides.length),
      );
    });

    test('replace swaps the draft and still preserves ---', () {
      final replaced = FrameworkTemplates.apply(
        current: 'existing draft\n\n---\n\nkeep me',
        template: FrameworkTemplates.fiveStepBreakdown,
        mode: TemplateInsertMode.replace,
      );

      expect(replaced, FrameworkTemplates.fiveStepBreakdown.markdown);
      expect(replaced, isNot(contains('keep me')));
      expect(CarouselDeck.fromMarkdown(replaced).slides, hasLength(2));
    });

    test(
      'a blank draft inserts the template without an empty leading slide',
      () {
        final applied = FrameworkTemplates.apply(
          current: '   \n',
          template: FrameworkTemplates.storyAndLesson,
          mode: TemplateInsertMode.append,
        );
        expect(applied, FrameworkTemplates.storyAndLesson.markdown);
        expect(CarouselDeck.fromMarkdown(applied).slides.first, isNotEmpty);
      },
    );
  });

  group('creator power-up widgets', () {
    testWidgets('HUD focus switches platform limits and fold tracks breaks', (
      tester,
    ) async {
      final markdown = '${'a' * 40}\n${'b' * 240}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LinkedInFoldIndicator(markdown: markdown),
                PlatformCounterHud(markdown: markdown),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('platform-focus-linkedIn')), findsOneWidget);
      expect(find.textContaining('LinkedIn 281/3000'), findsOneWidget);
      expect(find.textContaining('2 words · 1 min'), findsOneWidget);
      expect(find.byKey(const Key('linkedin-hook-warning')), findsOneWidget);
      expect(find.byKey(const Key('linkedin-fold-indicator')), findsOneWidget);
      expect(find.text('Opening hook is 281 characters'), findsNothing);
      expect(find.textContaining('Line breaks at'), findsNothing);

      await tester.tap(find.byKey(const Key('platform-focus-linkedIn')));
      await tester.pump();

      expect(find.byKey(const Key('platform-focus-x')), findsOneWidget);
      expect(find.textContaining('X 281/280'), findsOneWidget);

      await tester.tap(find.byKey(const Key('platform-focus-x')));
      await tester.pump();

      expect(find.byKey(const Key('platform-focus-threads')), findsOneWidget);
      expect(find.textContaining('Threads 281/500'), findsOneWidget);
    });

    testWidgets('keyboard hides the export bar and drag-dismiss is enabled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final storage = DraftStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('export-toolbar')), findsNothing);
      expect(find.byKey(const Key('formatting-toolbar')), findsOneWidget);
      expect(find.byKey(const Key('platform-counter-hud')), findsOneWidget);
      expect(find.byKey(const Key('dismiss-keyboard')), findsOneWidget);

      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('scratchpad-editor-scroll')),
      );
      expect(
        scroll.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgets('dismiss keyboard button clears editor focus', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = DraftStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('scratchpad-field')));
      await tester.pump();
      final editor = tester.widget<QuillEditor>(
        find.byKey(const Key('scratchpad-field')),
      );
      expect(editor.focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('dismiss-keyboard')));
      await tester.pump();
      expect(editor.focusNode.hasFocus, isFalse);
    });

    testWidgets('empty draft inserts a framework without a confirm dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = DraftStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('format-templates')));
      await tester.tap(find.byKey(const Key('format-templates')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('template-contrarian-hook')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('template-insert-dialog')), findsNothing);
      final content = ProviderScope.containerOf(
        tester.element(find.byType(ScratchpadScreen)),
      ).read(scratchpadProvider).content;
      expect(content, contains('Most people think [common belief] is true.'));
      expect(CarouselDeck.fromMarkdown(content).slides, hasLength(2));
    });

    testWidgets('a written draft asks to append or replace', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = DraftStorage();
      await storage.createDraft(initialContent: 'Keep this draft');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('format-templates')));
      await tester.tap(find.byKey(const Key('format-templates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template-story-lesson')));
      await tester.pumpAndSettle();

      expect(find.text('Append to existing text'), findsOneWidget);
      expect(find.text('Replace current draft'), findsOneWidget);

      await tester.tap(find.byKey(const Key('template-append')));
      await tester.pumpAndSettle();

      final content = ProviderScope.containerOf(
        tester.element(find.byType(ScratchpadScreen)),
      ).read(scratchpadProvider).content;
      expect(content, startsWith('Keep this draft'));
      expect(content, contains('### Lesson 1...'));
      expect(CarouselDeck.fromMarkdown(content).slides, hasLength(2));
      expect(
        CarouselDeck.fromMarkdown(deltaToMarkdown(markdownToDelta(content)))
            .slides,
        hasLength(2),
      );
    });
  });
}
