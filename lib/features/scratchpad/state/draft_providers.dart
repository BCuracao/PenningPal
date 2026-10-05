import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draft_item.dart';
import '../storage/draft_storage.dart';
import 'scratchpad_notifier.dart';

/// Local draft store. Production `main()` overrides this with a Hive-backed
/// instance; tests use the default in-memory [DraftStorage].
final draftStorageProvider = Provider<DraftStorage>((ref) => DraftStorage());

final draftListProvider =
    NotifierProvider<DraftListNotifier, List<DraftItem>>(DraftListNotifier.new);

/// In-memory index of every locally stored draft, newest first.
class DraftListNotifier extends Notifier<List<DraftItem>> {
  @override
  List<DraftItem> build() {
    final storage = ref.watch(draftStorageProvider);
    storage.ensureActiveDraft();
    return storage.listDrafts();
  }

  Future<void> refresh() async {
    state = ref.read(draftStorageProvider).listDrafts();
  }

  void replaceWith(List<DraftItem> drafts) {
    state = drafts;
  }
}

/// Id of the document bound to the scratchpad editor.
///
/// Implemented as a [Notifier] because Riverpod 3 keeps [StateProvider] in
/// `package:flutter_riverpod/legacy.dart`. [ActiveDraftIdNotifier.select]
/// flushes the open draft before loading [id].
final activeDraftIdProvider =
    NotifierProvider<ActiveDraftIdNotifier, String>(ActiveDraftIdNotifier.new);

class ActiveDraftIdNotifier extends Notifier<String> {
  @override
  String build() {
    final storage = ref.watch(draftStorageProvider);
    storage.ensureActiveDraft();
    return storage.getActiveDraftId() ?? '';
  }

  void update(String id) {
    if (state == id) return;
    state = id;
  }

  /// Flushes pending edits, then loads [id] into the scratchpad.
  Future<void> select(String id) {
    return ref.read(scratchpadProvider.notifier).switchDraft(id);
  }
}

/// The draft currently open in the editor, or null when the id is unknown.
final activeDraftProvider = Provider<DraftItem?>((ref) {
  final id = ref.watch(activeDraftIdProvider);
  if (id.isEmpty) return null;
  for (final draft in ref.watch(draftListProvider)) {
    if (draft.id == id) return draft;
  }
  return null;
});

/// Drawer search box. Matches title and markdown body.
final draftSearchQueryProvider =
    NotifierProvider<DraftSearchQueryNotifier, String>(
  DraftSearchQueryNotifier.new,
);

class DraftSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }
}

/// Drawer status chips.
enum DraftStatusFilter {
  all('All'),
  drafts('Drafts'),
  ready('Ready'),
  published('Published');

  const DraftStatusFilter(this.label);

  final String label;

  DraftStatus? get status {
    return switch (this) {
      DraftStatusFilter.all => null,
      DraftStatusFilter.drafts => DraftStatus.draft,
      DraftStatusFilter.ready => DraftStatus.ready,
      DraftStatusFilter.published => DraftStatus.published,
    };
  }
}

final draftStatusFilterProvider =
    NotifierProvider<DraftStatusFilterNotifier, DraftStatusFilter>(
  DraftStatusFilterNotifier.new,
);

class DraftStatusFilterNotifier extends Notifier<DraftStatusFilter> {
  @override
  DraftStatusFilter build() => DraftStatusFilter.all;

  void select(DraftStatusFilter filter) {
    state = filter;
  }
}

/// Drafts visible in the drawer after the search box and status chips.
final filteredDraftsProvider = Provider<List<DraftItem>>((ref) {
  return filterDrafts(
    ref.watch(draftListProvider),
    query: ref.watch(draftSearchQueryProvider),
    status: ref.watch(draftStatusFilterProvider),
  );
});

/// Pure filter used by [filteredDraftsProvider]. List order is preserved.
List<DraftItem> filterDrafts(
  List<DraftItem> drafts, {
  required String query,
  required DraftStatusFilter status,
}) {
  final needle = query.trim().toLowerCase();
  final requiredStatus = status.status;
  return [
    for (final draft in drafts)
      if (_matchesDraft(draft, needle, requiredStatus)) draft,
  ];
}

bool _matchesDraft(DraftItem draft, String needle, DraftStatus? status) {
  if (status != null && draft.status != status) return false;
  if (needle.isEmpty) return true;
  return draft.title.toLowerCase().contains(needle) ||
      draft.markdownContent.toLowerCase().contains(needle);
}
