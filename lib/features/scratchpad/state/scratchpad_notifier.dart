import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/draft_storage.dart';
import 'draft_list_notifier.dart';
import 'scratchpad_state.dart';

export 'draft_list_notifier.dart' show draftStorageProvider, draftListProvider;

/// Debounce window before a content change is flushed to [DraftStorage].
const Duration kScratchpadSaveDebounce = Duration(milliseconds: 400);

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
    return ScratchpadState.fromDraft(storage.ensureActiveDraft());
  }

  /// Updates live stats immediately and schedules a 400ms debounced persist.
  void updateContent(String newContent) {
    _unsavedContent = newContent;
    state = ScratchpadState.fromContent(
      newContent,
      isSaving: true,
      activeDraftId: state.activeDraftId,
    );
    _debounce?.cancel();
    _debounce = Timer(kScratchpadSaveDebounce, () => _persist(newContent));
  }

  /// Flushes the current buffer, loads [id], and refreshes word/slide stats.
  Future<void> switchDraft(String id) async {
    if (id == state.activeDraftId) return;
    await _flushPending();
    final storage = _storage;
    if (storage == null) return;
    final draft = await storage.getDraft(id);
    if (draft == null) return;
    await storage.setActiveDraftId(id);
    _unsavedContent = null;
    state = ScratchpadState.fromDraft(draft);
    await _refreshList();
  }

  /// Creates a blank draft, persists it, and makes it active.
  Future<Draft> createNewDraft({String initialContent = ''}) async {
    await _flushPending();
    final storage = _storage;
    if (storage == null) {
      return Draft(
        id: '',
        title: Draft.untitled,
        content: initialContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final draft = await storage.createDraft(initialContent: initialContent);
    _unsavedContent = null;
    state = ScratchpadState.fromDraft(draft);
    await _refreshList();
    return draft;
  }

  Future<void> deleteDraftById(String id) async {
    final storage = _storage;
    if (storage == null) return;
    if (id == state.activeDraftId) {
      await _flushPending();
    }
    await storage.deleteDraft(id);
    if (id == state.activeDraftId) {
      final remaining = await storage.getAllDrafts();
      if (remaining.isEmpty) {
        final created = await storage.createDraft();
        _unsavedContent = null;
        state = ScratchpadState.fromDraft(created);
      } else {
        await storage.setActiveDraftId(remaining.first.id);
        _unsavedContent = null;
        state = ScratchpadState.fromDraft(remaining.first);
      }
    }
    await _refreshList();
  }

  Future<void> renameActiveDraft(String title) async {
    final storage = _storage;
    if (storage == null) return;
    await _flushPending();
    final existing = await storage.getDraft(state.activeDraftId);
    if (existing == null) return;
    final trimmed = title.trim().isEmpty ? Draft.untitled : title.trim();
    final updated = existing.copyWith(
      title: trimmed,
      updatedAt: DateTime.now(),
    );
    await storage.saveDraft(updated);
    state = state.copyWith(title: trimmed, isSaving: false);
    await _refreshList();
  }

  Future<void> _persist(String content) async {
    final storage = _storage;
    if (storage == null) return;
    final existing = await storage.getDraft(state.activeDraftId) ??
        storage.ensureActiveDraft();
    final now = DateTime.now();
    await storage.saveDraft(
      existing.copyWith(
        content: content,
        title: Draft.inferTitle(content),
        updatedAt: now,
      ),
    );
    if (_unsavedContent == content) {
      _unsavedContent = null;
    }
    if (!ref.mounted) return;
    if (state.content == content) {
      state = state.copyWith(
        isSaving: false,
        title: Draft.inferTitle(content),
      );
    }
    await _refreshList();
  }

  Future<void> _flushPending() async {
    _debounce?.cancel();
    _debounce = null;
    final pending = _unsavedContent;
    _unsavedContent = null;
    if (pending != null) {
      await _persist(pending);
    }
  }

  Future<void> _refreshList() async {
    if (!ref.mounted) return;
    await ref.read(draftListProvider.notifier).refresh();
  }

  void _disposeTimer() {
    _debounce?.cancel();
    _debounce = null;
    final pending = _unsavedContent;
    _unsavedContent = null;
    if (pending == null) return;
    final storage = _storage;
    if (storage == null) return;
    final existing = storage.getActiveDraft() ?? storage.ensureActiveDraft();
    storage.saveDraft(
      existing.copyWith(
        content: pending,
        title: Draft.inferTitle(pending),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
