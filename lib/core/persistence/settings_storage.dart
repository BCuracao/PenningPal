import 'package:hive_flutter/hive_flutter.dart';

/// Default author profile used by the card exporter.
class CardSettings {
  const CardSettings({
    this.authorName = '',
    this.authorHandle = '',
    this.avatarPreset = 0,
  });

  static const CardSettings defaults = CardSettings();

  static const int avatarPresetCount = 6;

  final String authorName;
  final String authorHandle;
  final int avatarPreset;

  /// Handle preferred, then name. `null` when both are empty so the canvas
  /// can fall back to its built-in brand slot.
  String? get formattedAuthor {
    final handle = formattedHandle;
    if (handle != null) return handle;
    final name = authorName.trim();
    if (name.isNotEmpty) return name;
    return null;
  }

  /// Normalized `@handle`, or `null` when unset.
  String? get formattedHandle {
    final handle = authorHandle.trim();
    if (handle.isEmpty) return null;
    return handle.startsWith('@') ? handle : '@$handle';
  }

  String get initials {
    final source = authorName.trim().isNotEmpty
        ? authorName.trim()
        : authorHandle.trim().replaceFirst(RegExp(r'^@'), '');
    if (source.isEmpty) return '?';
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      final word = parts.first;
      final end = word.length < 2 ? word.length : 2;
      return word.substring(0, end).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  CardSettings copyWith({
    String? authorName,
    String? authorHandle,
    int? avatarPreset,
  }) {
    return CardSettings(
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      avatarPreset: (avatarPreset ?? this.avatarPreset)
          .clamp(0, avatarPresetCount - 1)
          .toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authorName': authorName,
      'authorHandle': authorHandle,
      'avatarPreset': avatarPreset,
    };
  }

  static CardSettings fromMap(Map<dynamic, dynamic> map) {
    final preset = map['avatarPreset'];
    return CardSettings(
      authorName: map['authorName'] as String? ?? '',
      authorHandle: map['authorHandle'] as String? ?? '',
      avatarPreset: preset is int ? preset : 0,
    );
  }
}

/// Local Hive wrapper for author / app settings. In-memory fallback when
/// [init] is skipped (unit tests).
class SettingsStorage {
  SettingsStorage();

  SettingsStorage.withBox(Box<dynamic> box) : _box = box;

  static const String boxName = 'settings_box';
  static const String _settingsKey = 'card_settings';

  Box<dynamic>? _box;
  final Map<String, dynamic> _memory = <String, dynamic>{};

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
  }

  CardSettings load() {
    final value = _read(_settingsKey);
    if (value is Map) return CardSettings.fromMap(value);
    return CardSettings.defaults;
  }

  Future<void> save(CardSettings settings) async {
    await _write(_settingsKey, settings.toMap());
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
}
