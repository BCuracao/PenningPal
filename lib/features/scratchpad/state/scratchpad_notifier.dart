import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/draft_storage.dart';
import 'scratchpad_state.dart';

/// Debounce window before a content change is flushed to [DraftStorage].
const Duration kScratchpadSaveDebounce = Duration(milliseconds: 400);

/// Local draft store. Production `main()` overrides this with a Hive-backed
/// instance; tests use the default in-memory [DraftStorage].
final draftStorageProvider = Provider<DraftStorage>((ref) => DraftStorage());

final scratchpadProvider =
    NotifierProvider<ScratchpadNotifier, ScratchpadState>(ScratchpadNotifier.new);

/// Holds scratchpad content, live stats, and debounced auto-save.
class ScratchpadNotifier extends Notifier<ScratchpadState> {
  Timer? _debounce;
  String? _unsavedContent;
  DraftStorage? _storage;

  @override
  ScratchpadState build() {
    final storage = ref.watch(draftStorageProvider);
    _storage = storage;
    ref.onDispose(_disposeTimer);
    return ScratchpadState.fromContent(storage.loadDraft());
  }

  /// Updates live stats immediately and schedules a 400ms debounced persist.
  void updateContent(String newContent) {
    _unsavedContent = newContent;
    state = ScratchpadState.fromContent(newContent, isSaving: true);
    _debounce?.cancel();
    _debounce = Timer(kScratchpadSaveDebounce, () => _persist(newContent));
  }

  Future<void> _persist(String content) async {
    final storage = _storage;
    if (storage == null) return;
    await storage.saveDraft(content);
    if (_unsavedContent == content) {
      _unsavedContent = null;
    }
    if (!ref.mounted) return;
    if (state.content == content) {
      state = state.copyWith(isSaving: false);
    }
  }

  void _disposeTimer() {
    _debounce?.cancel();
    _debounce = null;
    final pending = _unsavedContent;
    _unsavedContent = null;
    if (pending != null) {
      _storage?.saveDraft(pending);
    }
  }
}
