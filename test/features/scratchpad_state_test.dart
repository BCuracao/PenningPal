import 'dart:io';

import 'package:clean_canvas/core/persistence/draft_storage.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:clean_canvas/features/scratchpad/state/scratchpad_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ScratchpadState word count', () {
    test('empty string is zero', () {
      expect(ScratchpadState.countWords(''), 0);
      expect(ScratchpadState.fromContent('').wordCount, 0);
    });

    test('whitespace-only text is zero', () {
      expect(ScratchpadState.countWords('   '), 0);
      expect(ScratchpadState.countWords('\n\t  \n'), 0);
    });

    test('collapses multiple spaces', () {
      expect(ScratchpadState.countWords('hello   world'), 2);
      expect(ScratchpadState.countWords('  one   two  three  '), 3);
    });

    test('splits mixed punctuation', () {
      expect(ScratchpadState.countWords('Hello, world!'), 2);
      expect(ScratchpadState.countWords('one,two;three'), 3);
      expect(ScratchpadState.countWords('wait...what?'), 2);
    });

    test('counts a single token', () {
      expect(ScratchpadState.countWords('Canvas'), 1);
    });
  });

  group('ScratchpadState character count', () {
    test('empty string is zero', () {
      expect(ScratchpadState.fromContent('').charCount, 0);
    });

    test('includes spaces and punctuation', () {
      expect(ScratchpadState.fromContent('Hello, world!').charCount, 13);
      expect(ScratchpadState.fromContent('a b').charCount, 3);
    });

    test('matches raw string length', () {
      const text = 'Markdown **bold**\nline';
      expect(ScratchpadState.fromContent(text).charCount, text.length);
    });
  });

  group('ScratchpadState reading time', () {
    test('empty draft is zero minutes', () {
      expect(ScratchpadState.estimateReadMinutes(0), 0);
      expect(ScratchpadState.fromContent('').estimatedReadMinutes, 0);
    });

    test('rounds up at ~200 words per minute', () {
      expect(ScratchpadState.estimateReadMinutes(1), 1);
      expect(ScratchpadState.estimateReadMinutes(200), 1);
      expect(ScratchpadState.estimateReadMinutes(201), 2);
    });
  });

  group('ScratchpadNotifier', () {
    test('loads the persisted draft on launch', () async {
      final storage = DraftStorage();
      await storage.saveDraft('restored draft');

      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(scratchpadProvider);
      expect(state.content, 'restored draft');
      expect(state.wordCount, 2);
      expect(state.charCount, 'restored draft'.length);
      expect(state.isSaving, isFalse);
    });

    test('updateContent refreshes counts immediately', () {
      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(DraftStorage()),
        ],
      );
      addTearDown(container.dispose);

      container.read(scratchpadProvider.notifier).updateContent('Hello, world!');
      final state = container.read(scratchpadProvider);
      expect(state.content, 'Hello, world!');
      expect(state.wordCount, 2);
      expect(state.charCount, 13);
      expect(state.estimatedReadMinutes, 1);
      expect(state.isSaving, isTrue);
    });

    test('debounces persistence at 400ms and coalesces keystrokes', () async {
      final storage = DraftStorage();
      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scratchpadProvider.notifier);
      notifier.updateContent('a');
      notifier.updateContent('ab');
      notifier.updateContent('abc');

      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(storage.loadDraft(), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(storage.loadDraft(), 'abc');
      expect(container.read(scratchpadProvider).isSaving, isFalse);
      expect(storage.loadUpdatedAt(), isNotNull);
    });
  });

  group('DraftStorage', () {
    test('memory save/load/clear round-trip', () async {
      final storage = DraftStorage();
      expect(storage.loadDraft(), isEmpty);
      expect(storage.loadUpdatedAt(), isNull);

      await storage.saveDraft('hello');
      expect(storage.loadDraft(), 'hello');
      expect(storage.loadUpdatedAt(), isNotNull);
      expect(storage.loadActiveDraft()?.id, DraftStorage.activeDraftId);

      await storage.clearDraft();
      expect(storage.loadDraft(), isEmpty);
      expect(storage.loadUpdatedAt(), isNull);
    });

    test('Hive box save/load/clear round-trip', () async {
      final dir = await Directory.systemTemp.createTemp('clean_canvas_drafts_');
      Hive.init(dir.path);
      final boxName = 'drafts_box_${dir.hashCode}';
      final box = await Hive.openBox<dynamic>(boxName);
      addTearDown(() async {
        if (box.isOpen) await box.close();
        await Hive.deleteBoxFromDisk(boxName);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      final storage = DraftStorage.withBox(box);
      await storage.saveDraft('persisted');
      expect(storage.loadDraft(), 'persisted');
      expect(storage.loadUpdatedAt(), isNotNull);

      await storage.clearDraft();
      expect(storage.loadDraft(), isEmpty);
      expect(storage.loadUpdatedAt(), isNull);
    });
  });

  group('ScratchpadScreen', () {
    testWidgets('updates counts when text is entered', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ScratchpadScreen()),
        ),
      );

      expect(find.text('0 words'), findsOneWidget);
      expect(find.text('0 chars'), findsOneWidget);
      expect(find.text('0 min read'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello, world!');
      await tester.pump();

      expect(find.text('2 words'), findsOneWidget);
      expect(find.text('13 chars'), findsOneWidget);
      expect(find.text('1 min read'), findsOneWidget);
      expect(find.text('Saving...'), findsOneWidget);

      await tester.pump(kScratchpadSaveDebounce);
      expect(find.text('Saved'), findsOneWidget);
    });
  });
}
