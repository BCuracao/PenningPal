import 'dart:io';

import 'package:clean_canvas/core/persistence/draft_storage.dart';
import 'package:clean_canvas/core/persistence/settings_storage.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:clean_canvas/features/scratchpad/presentation/drafts_drawer.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/presentation/settings_bottom_sheet.dart';
import 'package:clean_canvas/features/scratchpad/state/draft_presentation.dart';
import 'package:clean_canvas/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Draft.inferTitle', () {
    test('extracts a markdown heading', () {
      expect(Draft.inferTitle('# Heading\n\nBody copy'), 'Heading');
      expect(Draft.inferTitle('## Nested title'), 'Nested title');
    });

    test('strips bold markdown tokens', () {
      expect(Draft.inferTitle('**Bold Title**\nMore text'), 'Bold Title');
    });

    test('uses the first plain-text line', () {
      expect(Draft.inferTitle('Plain text title\nSecond line'), 'Plain text title');
    });

    test('skips blank lines and falls back to Untitled Draft', () {
      expect(Draft.inferTitle(''), Draft.untitled);
      expect(Draft.inferTitle('   \n\n  '), Draft.untitled);
      expect(Draft.inferTitle('\n# Ready'), 'Ready');
    });
  });

  group('DraftStorage CRUD', () {
    test('create, list, get, save, and delete round-trip in memory', () async {
      final storage = DraftStorage();
      expect(await storage.getAllDrafts(), isEmpty);

      final created = await storage.createDraft(initialContent: '# Hello\nWorld');
      expect(created.title, 'Hello');
      expect(created.content, '# Hello\nWorld');
      expect(created.id, isNotEmpty);
      expect(storage.getActiveDraftId(), created.id);

      final fetched = await storage.getDraft(created.id);
      expect(fetched, created);

      final edited = created.copyWith(
        content: '# Hello\nUpdated body',
        title: Draft.inferTitle('# Hello\nUpdated body'),
        updatedAt: DateTime.now(),
      );
      await storage.saveDraft(edited);
      expect((await storage.getDraft(created.id))?.content, '# Hello\nUpdated body');

      final listed = await storage.getAllDrafts();
      expect(listed, hasLength(1));
      expect(listed.single.id, created.id);

      await storage.deleteDraft(created.id);
      expect(await storage.getAllDrafts(), isEmpty);
      expect(await storage.getDraft(created.id), isNull);
    });

    test('getAllDrafts sorts by updatedAt descending', () async {
      final storage = DraftStorage();
      final older = await storage.createDraft(initialContent: 'Older');
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final newer = await storage.createDraft(initialContent: 'Newer');

      final listed = await storage.getAllDrafts();
      expect(listed.map((draft) => draft.id).toList(), [newer.id, older.id]);
    });

    test('Hive box persists multiple drafts', () async {
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
      final draft = await storage.createDraft(initialContent: 'persisted');
      expect((await storage.getDraft(draft.id))?.content, 'persisted');

      final second = await storage.createDraft(initialContent: 'another');
      expect(await storage.getAllDrafts(), hasLength(2));
      expect(storage.getActiveDraftId(), second.id);

      await storage.deleteDraft(second.id);
      expect(storage.getActiveDraftId(), draft.id);
    });

    test('migrates the legacy single-draft keys without losing content', () async {
      final dir = await Directory.systemTemp.createTemp('clean_canvas_legacy_');
      Hive.init(dir.path);
      final boxName = 'drafts_box_legacy_${dir.hashCode}';
      final box = await Hive.openBox<dynamic>(boxName);
      addTearDown(() async {
        if (box.isOpen) await box.close();
        await Hive.deleteBoxFromDisk(boxName);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      await box.put(DraftStorage.legacyIdKey, DraftStorage.legacyActiveDraftId);
      await box.put(DraftStorage.legacyContentKey, '# Legacy note\nKeep me');
      await box.put(DraftStorage.legacyUpdatedAtKey, DateTime(2026, 1, 15));

      final storage = DraftStorage.withBox(box);
      final drafts = await storage.getAllDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.single.content, '# Legacy note\nKeep me');
      expect(drafts.single.title, 'Legacy note');
      expect(drafts.single.updatedAt, DateTime(2026, 1, 15));
      expect(box.containsKey(DraftStorage.legacyContentKey), isFalse);
      expect(box.containsKey(DraftStorage.legacyIdKey), isFalse);
      expect(box.containsKey(DraftStorage.legacyUpdatedAtKey), isFalse);
    });
  });

  group('switching drafts and timestamps', () {
    test('switching active id does not rewrite updatedAt', () async {
      final storage = DraftStorage();
      final first = await storage.createDraft(initialContent: 'Alpha');
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final second = await storage.createDraft(initialContent: 'Beta');
      expect(second.updatedAt.isAfter(first.updatedAt), isTrue);

      await storage.setActiveDraftId(first.id);
      final reloaded = await storage.getDraft(first.id);
      expect(reloaded?.updatedAt, first.updatedAt);
      expect(storage.getActiveDraftId(), first.id);
    });

    test('saving the switched draft updates timestamp and sort order', () async {
      final storage = DraftStorage();
      final first = await storage.createDraft(initialContent: 'Alpha');
      await Future<void>.delayed(const Duration(milliseconds: 3));
      await storage.createDraft(initialContent: 'Beta');

      await storage.setActiveDraftId(first.id);
      final later = DateTime.now().add(const Duration(seconds: 1));
      await storage.saveDraft(
        first.copyWith(
          content: 'Alpha edited',
          title: Draft.inferTitle('Alpha edited'),
          updatedAt: later,
        ),
      );

      final listed = await storage.getAllDrafts();
      expect(listed.first.id, first.id);
      expect(listed.first.updatedAt, later);
      expect(listed.first.content, 'Alpha edited');
    });

    test('scratchpadProvider switchDraft loads content and refreshes stats', () async {
      final storage = DraftStorage();
      final first = await storage.createDraft(initialContent: 'Hello world');
      await Future<void>.delayed(const Duration(milliseconds: 3));
      await storage.createDraft(initialContent: 'Second draft here');

      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(scratchpadProvider).content, 'Second draft here');
      expect(container.read(scratchpadProvider).wordCount, 3);

      await container.read(scratchpadProvider.notifier).switchDraft(first.id);
      final state = container.read(scratchpadProvider);
      expect(state.activeDraftId, first.id);
      expect(state.content, 'Hello world');
      expect(state.wordCount, 2);
      expect(state.title, 'Hello world');
    });

    test('deleting the active draft loads the next most recent', () async {
      final storage = DraftStorage();
      final first = await storage.createDraft(initialContent: 'Alpha');
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final second = await storage.createDraft(initialContent: 'Beta');

      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(scratchpadProvider).activeDraftId, second.id);
      await container.read(scratchpadProvider.notifier).deleteDraftById(second.id);
      expect(container.read(scratchpadProvider).activeDraftId, first.id);
      expect(container.read(scratchpadProvider).content, 'Alpha');
      expect(await storage.getDraft(second.id), isNull);
    });

    test('createNewDraft flushes the current buffer then focuses a blank doc', () async {
      final storage = DraftStorage();
      final container = ProviderContainer(
        overrides: [
          draftStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scratchpadProvider.notifier);
      notifier.updateContent('# Kept title\nBody');
      await Future<void>.delayed(kScratchpadSaveDebounce + const Duration(milliseconds: 40));

      await notifier.createNewDraft();
      expect(container.read(scratchpadProvider).content, isEmpty);
      expect(container.read(scratchpadProvider).title, Draft.untitled);
      expect(await storage.getAllDrafts(), hasLength(2));
      expect(
        (await storage.getAllDrafts()).any((draft) => draft.content.contains('Kept title')),
        isTrue,
      );
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 9, 18, 12);

    test('describes recent and calendar-relative times', () {
      expect(formatRelativeTime(now, now: now), 'Just now');
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 2)), now: now),
        '2m ago',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        formatRelativeTime(DateTime(2026, 9, 17, 8), now: now),
        'Yesterday',
      );
    });
  });

  group('CardSettings', () {
    test('formats handle, initials, and fallbacks', () {
      expect(const CardSettings(authorHandle: 'canvas').formattedAuthor, '@canvas');
      expect(const CardSettings(authorHandle: '@canvas').formattedAuthor, '@canvas');
      expect(const CardSettings(authorName: 'Ada Lovelace').formattedAuthor, 'Ada Lovelace');
      expect(const CardSettings(authorName: 'Ada Lovelace').initials, 'AL');
      expect(const CardSettings().formattedAuthor, isNull);
      expect(const CardSettings().initials, '?');
    });
  });

  group('DraftsDrawer widget', () {
    Future<void> pumpWorkspace(
      WidgetTester tester, {
      required DraftStorage storage,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageProvider.overrideWithValue(storage),
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: false),
            ),
          ],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('menu opens the drawer with branding and New Post', (tester) async {
      final storage = DraftStorage();
      await storage.createDraft(initialContent: '# Hello');

      await pumpWorkspace(tester, storage: storage);

      expect(find.text('Hello'), findsWidgets);
      await tester.tap(find.byKey(const Key('drafts-menu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(const Key('drafts-drawer')), findsOneWidget);
      expect(find.byKey(const Key('drafts-brand')), findsOneWidget);
      expect(find.text('PenningPal'), findsOneWidget);
      expect(find.byKey(const Key('drafts-new-post')), findsOneWidget);
      expect(find.text('1 word'), findsWidgets);
      expect(find.text('1 slide'), findsWidgets);
    });

    testWidgets('New Post creates a blank draft and updates the title', (tester) async {
      final storage = DraftStorage();
      await storage.createDraft(initialContent: '# Existing');

      await pumpWorkspace(tester, storage: storage);
      await tester.tap(find.byKey(const Key('drafts-menu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const Key('drafts-new-post')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(Draft.untitled), findsWidgets);
      expect(await storage.getAllDrafts(), hasLength(2));
    });

    testWidgets('delete confirmation can be cancelled or accepted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('open-delete-dialog'),
                onPressed: () => confirmDraftDelete(context, 'Remove me'),
                child: const Text('Delete'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-delete-dialog')));
      await tester.pump();
      expect(find.byKey(const Key('draft-delete-dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('draft-delete-cancel')));
      await tester.pump();
      expect(find.byKey(const Key('draft-delete-dialog')), findsNothing);

      await tester.tap(find.byKey(const Key('open-delete-dialog')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('draft-delete-confirm')));
      await tester.pump();
      expect(find.byKey(const Key('draft-delete-dialog')), findsNothing);
    });

    testWidgets('Settings & Profile opens the settings sheet', (tester) async {
      await pumpWorkspace(tester, storage: DraftStorage());
      await tester.tap(find.byKey(const Key('drafts-menu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const Key('drafts-settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SettingsBottomSheet), findsOneWidget);
      expect(find.byKey(const Key('settings-restore')), findsOneWidget);
      expect(find.byKey(const Key('settings-version')), findsOneWidget);
    });
  });
}
