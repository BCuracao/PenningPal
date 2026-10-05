import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:penningpal/features/paywall/paywall_provider.dart';
import 'package:penningpal/features/scratchpad/models/draft_item.dart';
import 'package:penningpal/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:penningpal/features/scratchpad/state/draft_providers.dart';
import 'package:penningpal/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:penningpal/features/scratchpad/storage/draft_storage.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DraftItem', () {
    test('infers a title and round-trips status through a map', () {
      final item = DraftItem(
        id: 'abc',
        title: '',
        markdownContent: '# Launch plan\nShip it',
        status: DraftStatus.ready,
        createdAt: _fixed,
        updatedAt: _fixed,
      );
      final stored = DraftItem.fromMap(item.toMap());
      expect(DraftItem.inferTitle(item.markdownContent), 'Launch plan');
      expect(stored.markdownContent, '# Launch plan\nShip it');
      expect(stored.status, DraftStatus.ready);
      expect(stored.content, stored.markdownContent);
    });

    test('status labels use distinct colours', () {
      expect(DraftStatus.draft.displayName, 'Draft');
      expect(DraftStatus.ready.displayName, 'Ready');
      expect(DraftStatus.published.displayName, 'Published');
      expect(
        DraftStatus.draft.foreground,
        isNot(DraftStatus.ready.foreground),
      );
      expect(
        DraftStatus.ready.foreground,
        isNot(DraftStatus.published.foreground),
      );
      expect(
        DraftStatus.published.foreground,
        isNot(DraftStatus.draft.foreground),
      );
    });
  });

  group('DraftStorage multi-draft CRUD', () {
    test('creates, reads, updates, and deletes a draft', () async {
      final storage = DraftStorage();
      expect(await storage.getAllDrafts(), isEmpty);

      final created = await storage.createDraft(
        initialContent: '# Hello\nWorld',
      );
      expect(
        created.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(created.title, 'Hello');
      expect(created.markdownContent, '# Hello\nWorld');
      expect(created.status, DraftStatus.draft);
      expect(storage.getActiveDraftId(), created.id);

      final fetched = await storage.getDraft(created.id);
      expect(fetched, created);

      final edited = created.copyWith(
        markdownContent: '# Hello\nUpdated body',
        title: DraftItem.inferTitle('# Hello\nUpdated body'),
        status: DraftStatus.ready,
        updatedAt: DateTime.now(),
      );
      await storage.saveDraft(edited);
      final saved = await storage.getDraft(created.id);
      expect(saved?.markdownContent, '# Hello\nUpdated body');
      expect(saved?.status, DraftStatus.ready);
      expect(saved?.title, 'Hello');

      await storage.deleteDraft(created.id);
      expect(await storage.getAllDrafts(), isEmpty);
      expect(await storage.getDraft(created.id), isNull);
    });

    test('duplicateDraft titles the copy "[Title] (Copy)"', () async {
      final storage = DraftStorage();
      final original = await storage.createDraft(
        initialContent: '# Launch plan\nDetails',
      );
      await storage.saveDraft(
        original.copyWith(status: DraftStatus.published),
      );

      final copy = await storage.duplicateDraft(original.id);
      expect(copy, isNotNull);
      expect(copy!.id, isNot(original.id));
      expect(copy.title, 'Launch plan (Copy)');
      expect(copy.markdownContent, original.markdownContent);
      expect(copy.status, DraftStatus.published);
      expect(storage.getActiveDraftId(), original.id);
      expect(await storage.getAllDrafts(), hasLength(2));

      final blank = await storage.createDraft();
      final blankCopy = await storage.duplicateDraft(blank.id);
      expect(blankCopy?.title, 'Untitled Draft (Copy)');
    });

    test('migrates a legacy_draft string when the box has no drafts', () async {
      final box = await _openTempBox('legacy_draft_string');
      await box.put(DraftStorage.legacyDraftKey, '# Old post\nKeep this');

      final storage = DraftStorage.withBox(box);
      final drafts = await storage.getAllDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.single.markdownContent, '# Old post\nKeep this');
      expect(drafts.single.title, 'Old post');
      expect(drafts.single.status, DraftStatus.draft);
      expect(box.containsKey(DraftStorage.legacyDraftKey), isFalse);
      expect(storage.getActiveDraftId(), drafts.single.id);

      final again = DraftStorage.withBox(box);
      expect(await again.getAllDrafts(), hasLength(1));
    });

    test('migrates a legacy_draft map and keeps an existing draft', () async {
      final box = await _openTempBox('legacy_draft_map');
      await box.put(DraftStorage.legacyDraftKey, <String, dynamic>{
        'id': 'legacy-map',
        'title': 'Mapped',
        'markdownContent': 'Mapped body',
        'status': 'ready',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 2).toIso8601String(),
      });

      final storage = DraftStorage.withBox(box);
      final imported = await storage.getDraft('legacy-map');
      expect(imported?.title, 'Mapped');
      expect(imported?.markdownContent, 'Mapped body');
      expect(imported?.status, DraftStatus.ready);
      expect(imported?.updatedAt, DateTime(2026, 3, 2));

      final occupied = await _openTempBox('legacy_draft_kept');
      await occupied.put('draft:existing', <String, dynamic>{
        'id': 'existing',
        'title': 'Kept',
        'content': 'Kept body',
        'status': 'published',
        'createdAt': DateTime(2026, 2, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 2, 1).toIso8601String(),
      });
      await occupied.put(DraftStorage.legacyDraftKey, 'Do not import');

      final busy = DraftStorage.withBox(occupied);
      final drafts = await busy.getAllDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.single.id, 'existing');
      expect(drafts.single.status, DraftStatus.published);
      expect(occupied.containsKey(DraftStorage.legacyDraftKey), isTrue);
    });
  });

  group('draft filters', () {
    test('search and status chips narrow the drawer list', () async {
      final storage = DraftStorage();
      final alpha = await storage.createDraft(
        initialContent: '# Alpha hook\nBody copy',
      );
      await storage.saveDraft(alpha.copyWith(status: DraftStatus.ready));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final beta = await storage.createDraft(
        initialContent: 'Notes about shipping',
      );
      await storage.saveDraft(
        beta.copyWith(status: DraftStatus.published, title: 'Ship notes'),
      );

      final container = ProviderContainer(
        overrides: [draftStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final all = container.read(filteredDraftsProvider);
      expect(all.map((draft) => draft.id), [beta.id, alpha.id]);
      expect(container.read(activeDraftProvider)?.id, beta.id);

      container.read(draftSearchQueryProvider.notifier).setQuery('HOOK');
      expect(
        container.read(filteredDraftsProvider).map((draft) => draft.id),
        [alpha.id],
      );

      container.read(draftSearchQueryProvider.notifier).setQuery('shipping');
      expect(
        container.read(filteredDraftsProvider).single.title,
        'Ship notes',
      );

      container.read(draftSearchQueryProvider.notifier).setQuery('');
      container
          .read(draftStatusFilterProvider.notifier)
          .select(DraftStatusFilter.ready);
      expect(
        container.read(filteredDraftsProvider).single.status,
        DraftStatus.ready,
      );

      container
          .read(draftStatusFilterProvider.notifier)
          .select(DraftStatusFilter.drafts);
      expect(container.read(filteredDraftsProvider), isEmpty);

      container
          .read(draftStatusFilterProvider.notifier)
          .select(DraftStatusFilter.published);
      expect(
        container.read(filteredDraftsProvider).single.id,
        beta.id,
      );
    });

    test('filterDrafts matches title or body and keeps sort order', () {
      final older = DraftItem(
        id: 'older',
        title: 'Standup',
        markdownContent: 'Yesterday notes',
        status: DraftStatus.draft,
        createdAt: _fixed,
        updatedAt: _fixed,
      );
      final newer = DraftItem(
        id: 'newer',
        title: 'Launch',
        markdownContent: 'Standup follow-up',
        status: DraftStatus.ready,
        createdAt: _fixed,
        updatedAt: _fixed.add(const Duration(minutes: 5)),
      );

      expect(
        filterDrafts(
          [newer, older],
          query: 'standup',
          status: DraftStatusFilter.all,
        ).map((draft) => draft.id),
        ['newer', 'older'],
      );
      expect(
        filterDrafts(
          [newer, older],
          query: '',
          status: DraftStatusFilter.ready,
        ).single.id,
        'newer',
      );
    });
  });

  group('scratchpad binding', () {
    test('switching flushes pending edits and reloads the next draft', () async {
      final storage = DraftStorage();
      final first = await storage.createDraft(initialContent: 'Alpha');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await storage.createDraft(initialContent: 'Beta');

      final container = ProviderContainer(
        overrides: [draftStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scratchpadProvider.notifier);
      expect(container.read(activeDraftIdProvider), second.id);

      notifier.updateContent('# Beta edited\nMore');
      await container.read(activeDraftIdProvider.notifier).select(first.id);

      expect(container.read(scratchpadProvider).content, 'Alpha');
      expect(container.read(scratchpadProvider).title, 'Alpha');
      expect(container.read(activeDraftIdProvider), first.id);
      final flushed = await storage.getDraft(second.id);
      expect(flushed?.markdownContent, '# Beta edited\nMore');
      expect(flushed?.title, 'Beta edited');
    });

    test('auto-save keeps status and undo restores a deleted draft', () async {
      final storage = DraftStorage();
      final draft = await storage.createDraft(initialContent: 'Keep me');
      await storage.saveDraft(draft.copyWith(status: DraftStatus.ready));

      final container = ProviderContainer(
        overrides: [draftStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scratchpadProvider.notifier);
      notifier.updateContent('Keep me please');
      await Future<void>.delayed(
        kScratchpadSaveDebounce + const Duration(milliseconds: 40),
      );

      final saved = await storage.getDraft(draft.id);
      expect(saved?.markdownContent, 'Keep me please');
      expect(saved?.status, DraftStatus.ready);
      expect(container.read(scratchpadProvider).status, DraftStatus.ready);

      await notifier.setDraftStatus(draft.id, DraftStatus.published);
      expect(container.read(scratchpadProvider).status, DraftStatus.published);
      expect(
        (await storage.getDraft(draft.id))?.status,
        DraftStatus.published,
      );

      final removal = notifier.deleteDraftNow(draft.id);
      expect(removal, isNotNull);
      expect(await storage.getDraft(draft.id), isNull);
      expect(container.read(scratchpadProvider).content, isEmpty);

      await notifier.undoDelete(removal!);
      expect(
        (await storage.getDraft(draft.id))?.markdownContent,
        'Keep me please',
      );
      expect(container.read(scratchpadProvider).activeDraftId, draft.id);
      expect(container.read(scratchpadProvider).status, DraftStatus.published);
    });
  });

  group('drafts drawer filters', () {
    testWidgets('status chips hide other drafts and the pill updates status',
        (tester) async {
      final storage = DraftStorage();
      final ready = await storage.createDraft(initialContent: '# Ready post');
      storage.saveDraftSync(ready.copyWith(status: DraftStatus.ready));
      final published = await storage.createDraft(
        initialContent: '# Published post',
      );
      storage.saveDraftSync(
        published.copyWith(status: DraftStatus.published),
      );

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

      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
      expect(find.byKey(const Key('draft-status-pill')), findsOneWidget);
      expect(find.text('Published'), findsWidgets);

      await tester.tap(find.byKey(const Key('drafts-menu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(Key('draft-tile-${ready.id}')), findsOneWidget);
      expect(find.byKey(Key('draft-tile-${published.id}')), findsOneWidget);
      expect(find.text('New Draft'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('draft-filter-ready')));
      await tester.tap(find.byKey(const Key('draft-filter-ready')));
      await tester.pump();

      expect(find.byKey(Key('draft-tile-${ready.id}')), findsOneWidget);
      expect(find.byKey(Key('draft-tile-${published.id}')), findsNothing);

      tester.state<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('draft-status-pill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status-option-ready')));
      await tester.pumpAndSettle();

      expect(
        (await storage.getDraft(published.id))?.status,
        DraftStatus.ready,
      );
    });
  });
}

final DateTime _fixed = DateTime(2026, 4, 1, 9);

Future<Box<dynamic>> _openTempBox(String name) async {
  final dir = await Directory.systemTemp.createTemp('penningpal_$name');
  Hive.init(dir.path);
  final boxName = '${name}_${dir.hashCode}';
  final box = await Hive.openBox<dynamic>(boxName);
  addTearDown(() async {
    if (box.isOpen) await box.close();
    await Hive.deleteBoxFromDisk(boxName);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return box;
}
