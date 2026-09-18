import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight document stored in the `drafts_box` Hive box.
class Draft {
  const Draft({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String untitled = 'Untitled Draft';

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// First non-empty line, with heading markers and inline markdown stripped.
  ///
  /// Falls back to [untitled] when the buffer is empty or token-only.
  static String inferTitle(String content) {
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final stripped = stripMarkdownTokens(raw);
      if (stripped.isNotEmpty) return stripped;
    }
    return untitled;
  }

  /// Body preview used in the drafts list: first [maxChars] of text after
  /// the title line, with markdown tokens stripped.
  static String previewSnippet(String content, {int maxChars = 60}) {
    final lines = content.split(RegExp(r'\r?\n'));
    var skippedTitle = false;
    final buffer = StringBuffer();
    for (final raw in lines) {
      final stripped = stripMarkdownTokens(raw);
      if (stripped.isEmpty) continue;
      if (!skippedTitle) {
        skippedTitle = true;
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(stripped);
      if (buffer.length >= maxChars) break;
    }
    final snippet = buffer.toString().trim();
    if (snippet.length <= maxChars) return snippet;
    return snippet.substring(0, maxChars).trimRight();
  }

  /// Strips heading prefixes, list/quote markers, and common inline tokens.
  static String stripMarkdownTokens(String line) {
    var s = line.trim();
    if (s.isEmpty) return '';
    s = s.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    s = s.replaceFirst(RegExp(r'^>\s*'), '');
    s = s.replaceFirst(RegExp(r'^[-*+]\s+'), '');
    s = s.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    if (RegExp(r'^[-*_]{3,}$').hasMatch(s)) return '';
    s = s.replaceAllMapped(
      RegExp(r'\*\*\*([^*]+)\*\*\*'),
      (match) => match[1]!,
    );
    s = s.replaceAllMapped(RegExp(r'___([^_]+)___'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'__([^_]+)__'), (match) => match[1]!);
    s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (match) => match[1]!);
    s = s.replaceAllMapped(
      RegExp(r'(?<!\w)_([^_]+)_(?!\w)'),
      (match) => match[1]!,
    );
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match[1]!);
    return s.trim();
  }

  Draft copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Draft(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Draft fromMap(Map<dynamic, dynamic> map, {String? fallbackId}) {
    final id = map['id'] as String? ?? fallbackId ?? generateDraftId();
    final content = map['content'] as String? ?? '';
    final title = (map['title'] as String?)?.trim();
    return Draft(
      id: id,
      title: (title == null || title.isEmpty) ? inferTitle(content) : title,
      content: content,
      createdAt: parseTime(map['createdAt']) ??
          parseTime(map['updatedAt']) ??
          DateTime.now(),
      updatedAt: parseTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? parseTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is Draft &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, title, content, createdAt, updatedAt);
}

final Random _draftIdRandom = Random();

/// Timestamp + entropy id, unique even when two drafts are created together.
String generateDraftId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final entropy = _draftIdRandom.nextInt(0x7fffffff).toRadixString(16);
  return 'd_${now}_$entropy';
}

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

  /// Sorted by [Draft.updatedAt] descending (most recently edited first).
  Future<List<Draft>> getAllDrafts() async {
    return listDrafts();
  }

  /// Synchronous snapshot used by Riverpod `build()` methods.
  List<Draft> listDrafts() {
    _ensureMigratedSync();
    final drafts = <Draft>[];
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
  Future<Draft> createDraft({String initialContent = ''}) async {
    _ensureMigratedSync();
    final draft = _newDraft(initialContent: initialContent);
    await _putDraft(draft);
    await _write(_activeIdKey, draft.id);
    return draft;
  }

  /// Upserts [draft]. Empty titles are replaced with an inferred title.
  Future<void> saveDraft(Draft draft) async {
    _ensureMigratedSync();
    final titled = draft.title.trim().isEmpty
        ? draft.copyWith(title: Draft.inferTitle(draft.content))
        : draft;
    await _putDraft(titled);
  }

  Future<void> deleteDraft(String id) async {
    _ensureMigratedSync();
    await _delete(_draftKey(id));
    if (getActiveDraftId() == id) {
      final remaining = listDrafts();
      if (remaining.isNotEmpty) {
        await _write(_activeIdKey, remaining.first.id);
      } else {
        await _delete(_activeIdKey);
      }
    }
  }

  Future<Draft?> getDraft(String id) async {
    _ensureMigratedSync();
    return _readDraft(id);
  }

  String? getActiveDraftId() {
    _ensureMigratedSync();
    return _read(_activeIdKey) as String?;
  }

  Future<void> setActiveDraftId(String id) async {
    _ensureMigratedSync();
    await _write(_activeIdKey, id);
  }

  /// Active document, or `null` when the box has no drafts yet.
  Draft? getActiveDraft() {
    _ensureMigratedSync();
    final id = getActiveDraftId();
    if (id == null) return null;
    return _readDraft(id);
  }

  /// Guarantees an active draft exists (creates a blank one if needed).
  Draft ensureActiveDraft() {
    _ensureMigratedSync();
    final existing = getActiveDraft();
    if (existing != null) return existing;
    final draft = _newDraft();
    _putDraftSync(draft);
    _writeSync(_activeIdKey, draft.id);
    return draft;
  }

  String _draftKey(String id) => '$_draftKeyPrefix$id';

  Draft _newDraft({String initialContent = ''}) {
    final now = DateTime.now();
    return Draft(
      id: generateDraftId(),
      title: Draft.inferTitle(initialContent),
      content: initialContent,
      createdAt: now,
      updatedAt: now,
    );
  }

  Draft? _readDraft(String id) {
    return _decodeDraft(_read(_draftKey(id)), fallbackId: id);
  }

  Draft? _decodeDraft(dynamic value, {String? fallbackId}) {
    if (value is Map) {
      return Draft.fromMap(value, fallbackId: fallbackId);
    }
    return null;
  }

  Future<void> _putDraft(Draft draft) async {
    await _write(_draftKey(draft.id), draft.toMap());
  }

  void _putDraftSync(Draft draft) {
    _writeSync(_draftKey(draft.id), draft.toMap());
  }

  void _ensureMigratedSync() {
    if (_migrated) return;
    _migrateLegacySync();
    _migrated = true;
  }

  void _migrateLegacySync() {
    final version = _read(_schemaKey);
    if (version == _schemaVersion) {
      _deleteLegacyKeysSync();
      return;
    }

    final hasLegacy = _contains(legacyContentKey) ||
        _contains(legacyUpdatedAtKey) ||
        _contains(legacyIdKey);
    if (hasLegacy) {
      final content = _read(legacyContentKey) as String? ?? '';
      final updatedAt =
          Draft.parseTime(_read(legacyUpdatedAtKey)) ?? DateTime.now();
      final draft = Draft(
        id: generateDraftId(),
        title: Draft.inferTitle(content),
        content: content,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
      _putDraftSync(draft);
      _writeSync(_activeIdKey, draft.id);
      _deleteLegacyKeysSync();
    }
    _writeSync(_schemaKey, _schemaVersion);
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

  Future<void> _write(String key, dynamic value) async {
    _writeSync(key, value);
  }

  void _writeSync(String key, dynamic value) {
    final box = _box;
    if (box != null) {
      box.put(key, value);
      return;
    }
    _memory[key] = value;
  }

  Future<void> _delete(String key) async {
    _deleteSync(key);
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
