import 'package:hive_flutter/hive_flutter.dart';

import '../models/draft_item.dart';

/// Local-only Hive wrapper for scratchpad drafts.
///
/// Writes stay on-device. When [init] has not been called (unit tests),
/// an in-memory map is used so persistence logic can be exercised without
/// a Flutter plugin binding.
class DraftStorage {
  DraftStorage();

  /// Binds this instance to an already-opened Hive [box] (tests / custom init).
  DraftStorage.withBox(Box<dynamic> box) : _box = box;

  static const String boxName = 'drafts_box';

  /// Pre-multi-draft Hive keys (single document). Migrated on first access.
  static const String legacyActiveDraftId = 'active';
  static const String legacyIdKey = 'id';
  static const String legacyContentKey = 'content';
  static const String legacyUpdatedAtKey = 'updatedAt';

  /// Single-document blob used by older installs. Imported when [boxName]
  /// has no draft documents yet.
  static const String legacyDraftKey = 'legacy_draft';

  static const String _schemaKey = '__schema_version__';
  static const String _activeIdKey = '__active_id__';
  static const int _schemaVersion = 2;
  static const String _draftKeyPrefix = 'draft:';

  Box<dynamic>? _box;
  final Map<String, dynamic> _memory = <String, dynamic>{};
  bool _migrated = false;

  /// Initializes Hive (app documents directory) and opens [boxName].
  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      _ensureMigratedSync();
      return;
    }
    await Hive.initFlutter();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
    _ensureMigratedSync();
  }

  /// Sorted by [DraftItem.updatedAt] descending (most recently edited first).
  Future<List<DraftItem>> getAllDrafts() async {
    _ensureMigratedSync();
    return listDrafts();
  }

  /// Synchronous snapshot used by Riverpod `build()` methods.
  List<DraftItem> listDrafts() {
    _ensureMigratedSync();
    final drafts = <DraftItem>[];
    for (final key in _allKeys) {
      if (!key.startsWith(_draftKeyPrefix)) continue;
      final draft = _decodeDraft(
        _read(key),
        fallbackId: key.substring(_draftKeyPrefix.length),
      );
      if (draft != null) drafts.add(draft);
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  /// Creates a new document, persists it, and makes it the active draft.
  Future<DraftItem> createDraft({String initialContent = ''}) async {
    return createDraftSync(initialContent: initialContent);
  }

  DraftItem createDraftSync({String initialContent = ''}) {
    _ensureMigratedSync();
    final draft = _newDraft(initialContent: initialContent);
    _putDraftSync(draft);
    _writeSync(_activeIdKey, draft.id);
    return draft;
  }

  /// Upserts [draft]. Empty titles are replaced with an inferred title.
  Future<void> saveDraft(DraftItem draft) async {
    saveDraftSync(draft);
  }

  void saveDraftSync(DraftItem draft) {
    _ensureMigratedSync();
    final titled = draft.title.trim().isEmpty
        ? draft.copyWith(title: DraftItem.inferTitle(draft.markdownContent))
        : draft;
    _putDraftSync(titled);
  }

  Future<void> deleteDraft(String id) async {
    removeDraftSync(id);
  }

  /// Removes [id] and, when it was active, points the active id at the
  /// next most recently updated draft.
  DraftItem? removeDraftSync(String id) {
    _ensureMigratedSync();
    final existing = _readDraft(id);
    _deleteSync(_draftKey(id));
    if (getActiveDraftId() == id) {
      final remaining = listDrafts();
      if (remaining.isNotEmpty) {
        _writeSync(_activeIdKey, remaining.first.id);
      } else {
        _deleteSync(_activeIdKey);
      }
    }
    return existing;
  }

  Future<DraftItem?> getDraft(String id) async {
    _ensureMigratedSync();
    return _readDraft(id);
  }

  DraftItem? peekDraft(String id) {
    _ensureMigratedSync();
    return _readDraft(id);
  }

  /// Inserts a new draft with the same markdown and status.
  ///
  /// The copy is titled `"[Title] (Copy)"` and does not steal the active id.
  Future<DraftItem?> duplicateDraft(String id) async {
    _ensureMigratedSync();
    final source = _readDraft(id);
    if (source == null) return null;
    final now = DateTime.now();
    final baseTitle = source.title.trim().isEmpty
        ? DraftItem.inferTitle(source.markdownContent)
        : source.title.trim();
    final copy = source.copyWith(
      id: generateDraftId(),
      title: '$baseTitle (Copy)',
      createdAt: now,
      updatedAt: now,
    );
    _putDraftSync(copy);
    return copy;
  }

  String? getActiveDraftId() {
    _ensureMigratedSync();
    return _read(_activeIdKey) as String?;
  }

  Future<void> setActiveDraftId(String id) async {
    _ensureMigratedSync();
    _writeSync(_activeIdKey, id);
  }

  /// Active document, or `null` when the box has no drafts yet.
  DraftItem? getActiveDraft() {
    _ensureMigratedSync();
    final id = getActiveDraftId();
    if (id == null) return null;
    return _readDraft(id);
  }

  /// Guarantees an active draft exists (creates a blank one if needed).
  DraftItem ensureActiveDraft() {
    _ensureMigratedSync();
    final existing = getActiveDraft();
    if (existing != null) return existing;
    return createDraftSync();
  }

  String _draftKey(String id) => '$_draftKeyPrefix$id';

  DraftItem _newDraft({String initialContent = ''}) {
    final now = DateTime.now();
    return DraftItem(
      id: generateDraftId(),
      title: DraftItem.inferTitle(initialContent),
      markdownContent: initialContent,
      createdAt: now,
      updatedAt: now,
    );
  }

  DraftItem? _readDraft(String id) {
    return _decodeDraft(_read(_draftKey(id)), fallbackId: id);
  }

  DraftItem? _decodeDraft(dynamic value, {String? fallbackId}) {
    if (value is Map) {
      return DraftItem.fromMap(value, fallbackId: fallbackId);
    }
    return null;
  }

  void _putDraftSync(DraftItem draft) {
    _writeSync(_draftKey(draft.id), draft.toMap());
  }

  void _ensureMigratedSync() {
    if (_migrated) return;
    _migrateLegacySync();
    _migrated = true;
  }

  void _migrateLegacySync() {
    final hadDrafts = _hasDraftDocuments();
    if (!hadDrafts) {
      _importSplitLegacyIfPresent();
      if (_contains(legacyDraftKey)) {
        _importLegacyDraftValue(_read(legacyDraftKey));
        _deleteSync(legacyDraftKey);
      }
    }
    _deleteLegacyKeysSync();
    if (_read(_schemaKey) != _schemaVersion) {
      _writeSync(_schemaKey, _schemaVersion);
    }
  }

  bool _hasDraftDocuments() {
    for (final key in _allKeys) {
      if (key.startsWith(_draftKeyPrefix)) return true;
    }
    return false;
  }

  void _importSplitLegacyIfPresent() {
    final hasLegacy = _contains(legacyContentKey) ||
        _contains(legacyUpdatedAtKey) ||
        _contains(legacyIdKey);
    if (!hasLegacy) return;

    final content = _read(legacyContentKey) as String? ?? '';
    final updatedAt =
        DraftItem.parseTime(_read(legacyUpdatedAtKey)) ?? DateTime.now();
    final draft = DraftItem(
      id: generateDraftId(),
      title: DraftItem.inferTitle(content),
      markdownContent: content,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
    _putDraftSync(draft);
    _writeSync(_activeIdKey, draft.id);
  }

  void _importLegacyDraftValue(dynamic value) {
    final DraftItem? draft;
    if (value is String) {
      final now = DateTime.now();
      draft = DraftItem(
        id: generateDraftId(),
        title: DraftItem.inferTitle(value),
        markdownContent: value,
        createdAt: now,
        updatedAt: now,
      );
    } else if (value is Map) {
      draft = DraftItem.fromMap(Map<dynamic, dynamic>.from(value));
    } else {
      draft = null;
    }
    if (draft == null) return;
    _putDraftSync(draft);
    if (getActiveDraftId() == null) {
      _writeSync(_activeIdKey, draft.id);
    }
  }

  void _deleteLegacyKeysSync() {
    _deleteSync(legacyIdKey);
    _deleteSync(legacyContentKey);
    _deleteSync(legacyUpdatedAtKey);
  }

  Iterable<String> get _allKeys {
    final box = _box;
    if (box != null) {
      return box.keys.map((key) => key.toString());
    }
    return _memory.keys;
  }

  bool _contains(String key) {
    final box = _box;
    if (box != null) return box.containsKey(key);
    return _memory.containsKey(key);
  }

  dynamic _read(String key) {
    final box = _box;
    if (box != null) return box.get(key);
    return _memory[key];
  }

  void _writeSync(String key, dynamic value) {
    final box = _box;
    if (box != null) {
      box.put(key, value);
      return;
    }
    _memory[key] = value;
  }

  void _deleteSync(String key) {
    final box = _box;
    if (box != null) {
      box.delete(key);
      return;
    }
    _memory.remove(key);
  }
}
