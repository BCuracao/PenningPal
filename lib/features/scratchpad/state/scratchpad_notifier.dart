import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draft_item.dart';
import '../storage/draft_storage.dart';
import 'draft_providers.dart';
import 'scratchpad_state.dart';

export 'draft_providers.dart'
    show
        activeDraftIdProvider,
        activeDraftProvider,
        draftListProvider,
        draftSearchQueryProvider,
        draftStatusFilterProvider,
        draftStorageProvider,
        filteredDraftsProvider;

/// Debounce window before a content change is flushed to [DraftStorage].
const Duration kScratchpadSaveDebounce = Duration(milliseconds: 400);

final scratchpadProvider =
    NotifierProvider<ScratchpadNotifier, ScratchpadState>(ScratchpadNotifier.new);

/// Snapshot returned when a draft is removed, so the drawer can offer Undo.
class DraftRemoval {
  const DraftRemoval({
    required this.draft,
    required this.wasActive,
    this.replacementId,
  });

  final DraftItem draft;
  final bool wasActive;

  /// Blank draft created so the editor is never left without a document.
  final String? replacementId;
}

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
      status: state.status,
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
    final draft = storage.peekDraft(id);
    if (draft == null) return;
    await storage.setActiveDraftId(id);
    _unsavedContent = null;
    state = ScratchpadState.fromDraft(draft);
    _syncActiveId(id);
    await _refreshList();
  }

  /// Creates a blank draft, persists it, and makes it active.
  Future<DraftItem> createNewDraft({String initialContent = ''}) async {
    await _flushPending();
    final storage = _storage;
    if (storage == null) {
      return DraftItem(
        id: '',
        title: DraftItem.untitled,
        markdownContent: initialContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final draft = storage.createDraftSync(initialContent: initialContent);
    _unsavedContent = null;
    state = ScratchpadState.fromDraft(draft);
    _syncActiveId(draft.id);
    await _refreshList();
    return draft;
  }

  /// Removes [id]. When it was the open draft, the next newest draft is loaded.
  Future<DraftRemoval?> deleteDraftById(String id) async {
    final removal = deleteDraftNow(id);
    if (removal != null) {
      await _refreshList();
    }
    return removal;
  }

  /// Synchronous delete so a swipe can drop the row before the next frame.
  DraftRemoval? deleteDraftNow(String id) {
    final storage = _storage;
    if (storage == null) return null;
    final wasActive = id == state.activeDraftId;
    var snapshot = storage.peekDraft(id);
    if (snapshot == null) return null;
    if (wasActive && _unsavedContent != null) {
      _debounce?.cancel();
      _debounce = null;
      final pending = _unsavedContent!;
      _unsavedContent = null;
      snapshot = snapshot.copyWith(
        content: pending,
        title: DraftItem.inferTitle(pending),
        updatedAt: DateTime.now(),
      );
      storage.saveDraftSync(snapshot);
    }
    storage.removeDraftSync(id);
    String? replacementId;
    if (wasActive) {
      final activeId = storage.getActiveDraftId();
      if (activeId == null) {
        final created = storage.createDraftSync();
        replacementId = created.id;
        _unsavedContent = null;
        state = ScratchpadState.fromDraft(created);
        _syncActiveId(created.id);
      } else {
        final next = storage.peekDraft(activeId);
        if (next != null) {
          _unsavedContent = null;
          state = ScratchpadState.fromDraft(next);
          _syncActiveId(next.id);
        }
      }
    }
    ref.read(draftListProvider.notifier).replaceWith(storage.listDrafts());
    return DraftRemoval(
      draft: snapshot,
      wasActive: wasActive,
      replacementId: replacementId,
    );
  }

  /// Puts a deleted draft back. Restores the editor when it had been active.
  Future<void> undoDelete(DraftRemoval removal) async {
    final storage = _storage;
    if (storage == null) return;
    if (removal.replacementId != null) {
      storage.removeDraftSync(removal.replacementId!);
    }
    storage.saveDraftSync(removal.draft);
    if (removal.wasActive) {
      await storage.setActiveDraftId(removal.draft.id);
      _debounce?.cancel();
      _debounce = null;
      _unsavedContent = null;
      state = ScratchpadState.fromDraft(removal.draft);
      _syncActiveId(removal.draft.id);
    }
    await _refreshList();
  }

  /// Copies [id] as `"[Title] (Copy)"` without changing the open draft.
  Future<DraftItem?> duplicateDraftById(String id) async {
    final storage = _storage;
    if (storage == null) return null;
    if (id == state.activeDraftId) {
      await _flushPending();
    }
    final copy = await storage.duplicateDraft(id);
    await _refreshList();
    return copy;
  }

  /// Updates the workflow tag. The open draft's pill refreshes immediately.
  Future<void> setDraftStatus(String id, DraftStatus status) async {
    final storage = _storage;
    if (storage == null) return;
    if (id == state.activeDraftId) {
      await _flushPending();
    }
    final existing = storage.peekDraft(id);
    if (existing == null || existing.status == status) return;
    final updated = existing.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    storage.saveDraftSync(updated);
    if (!ref.mounted) return;
    if (state.activeDraftId == id) {
      state = state.copyWith(status: status, isSaving: false);
    }
    await _refreshList();
  }

  Future<void> renameActiveDraft(String title) async {
    final storage = _storage;
    if (storage == null) return;
    await _flushPending();
    final existing = storage.peekDraft(state.activeDraftId);
    if (existing == null) return;
    final trimmed = title.trim().isEmpty ? DraftItem.untitled : title.trim();
    final updated = existing.copyWith(
      title: trimmed,
      updatedAt: DateTime.now(),
    );
    storage.saveDraftSync(updated);
    state = state.copyWith(title: trimmed, isSaving: false);
    await _refreshList();
  }

  Future<void> _persist(String content) async {
    final storage = _storage;
    if (storage == null) return;
    final existing = storage.peekDraft(state.activeDraftId) ??
        storage.ensureActiveDraft();
    final now = DateTime.now();
    storage.saveDraftSync(
      existing.copyWith(
        content: content,
        title: DraftItem.inferTitle(content),
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
        title: DraftItem.inferTitle(content),
      );
    }
    _syncActiveId(state.activeDraftId);
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

  void _syncActiveId(String id) {
    if (!ref.mounted || id.isEmpty) return;
    ref.read(activeDraftIdProvider.notifier).update(id);
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
    storage.saveDraftSync(
      existing.copyWith(
        content: pending,
        title: DraftItem.inferTitle(pending),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
