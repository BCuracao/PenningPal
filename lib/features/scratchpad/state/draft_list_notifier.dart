import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/draft_storage.dart';

/// Local draft store. Production `main()` overrides this with a Hive-backed
/// instance; tests use the default in-memory [DraftStorage].
final draftStorageProvider = Provider<DraftStorage>((ref) => DraftStorage());

final draftListProvider =
    NotifierProvider<DraftListNotifier, List<Draft>>(DraftListNotifier.new);

/// In-memory index of every locally stored draft, newest first.
class DraftListNotifier extends Notifier<List<Draft>> {
  @override
  List<Draft> build() {
    final storage = ref.watch(draftStorageProvider);
    storage.ensureActiveDraft();
    return storage.listDrafts();
  }

  Future<void> refresh() async {
    state = await ref.read(draftStorageProvider).getAllDrafts();
  }
}
