import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight document stored in the `drafts_box` Hive box.
class Draft {
  const Draft({
    required this.id,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final DateTime updatedAt;
}

/// Local-only Hive wrapper for the active scratchpad draft.
///
/// Writes stay on-device. When [init] has not been called (unit tests),
/// an in-memory map is used so persistence logic can be exercised without
/// a Flutter plugin binding.
class DraftStorage {
  DraftStorage();

  /// Binds this instance to an already-opened Hive [box] (tests / custom init).
  DraftStorage.withBox(Box<dynamic> box) : _box = box;

  static const String boxName = 'drafts_box';
  static const String activeDraftId = 'active';

  static const String _idKey = 'id';
  static const String _contentKey = 'content';
  static const String _updatedAtKey = 'updatedAt';

  Box<dynamic>? _box;
  final Map<String, dynamic> _memory = <String, dynamic>{};

  /// Initializes Hive (app documents directory) and opens [boxName].
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
  }

  /// Persists [content] and stamps [Draft.updatedAt] with the current time.
  Future<void> saveDraft(String content) async {
    final now = DateTime.now();
    await _write(_idKey, activeDraftId);
    await _write(_contentKey, content);
    await _write(_updatedAtKey, now);
  }

  /// Returns the stored draft body, or an empty string when none exists.
  String loadDraft() {
    return _read(_contentKey) as String? ?? '';
  }

  /// Last write time, or `null` when no draft has been saved.
  DateTime? loadUpdatedAt() {
    final value = _read(_updatedAtKey);
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Active draft snapshot, or `null` when nothing has been saved yet.
  Draft? loadActiveDraft() {
    final updatedAt = loadUpdatedAt();
    if (updatedAt == null) return null;
    return Draft(
      id: _read(_idKey) as String? ?? activeDraftId,
      content: loadDraft(),
      updatedAt: updatedAt,
    );
  }

  /// Removes the active draft content and timestamp.
  Future<void> clearDraft() async {
    await _delete(_idKey);
    await _delete(_contentKey);
    await _delete(_updatedAtKey);
  }

  dynamic _read(String key) {
    final box = _box;
    if (box != null) return box.get(key);
    return _memory[key];
  }

  Future<void> _write(String key, dynamic value) async {
    final box = _box;
    if (box != null) {
      await box.put(key, value);
      return;
    }
    _memory[key] = value;
  }

  Future<void> _delete(String key) async {
    final box = _box;
    if (box != null) {
      await box.delete(key);
      return;
    }
    _memory.remove(key);
  }
}
