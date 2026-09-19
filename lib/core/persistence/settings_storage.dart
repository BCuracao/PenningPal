import 'package:hive_flutter/hive_flutter.dart';

import 'profile_storage.dart';

/// Default author profile used by the card exporter.
class CardSettings {
  const CardSettings({
    this.authorName = '',
    this.authorHandle = '',
    this.avatarPreset = 0,
    this.avatarPath,
    this.defaultFont = 'Inter',
    this.defaultThemeId = 'minimal',
    this.activeProfileId = '',
    this.customBackgroundColor = 0xFF0F172A,
    this.customTextColor = 0xFFF8FAFC,
    this.profiles = const [],
  });

  static const CardSettings defaults = CardSettings();

  static const int avatarPresetCount = 6;

  final String authorName;
  final String authorHandle;
  final int avatarPreset;
  final String? avatarPath;
  final String defaultFont;
  final String defaultThemeId;
  final String activeProfileId;
  final int customBackgroundColor;
  final int customTextColor;

  /// Runtime snapshot of [ProfileStorage.listProfiles]. Not persisted here.
  final List<AuthorProfile> profiles;

  AuthorProfile? get activeProfile {
    if (profiles.isEmpty) return null;
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.first;
  }

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
    String? avatarPath,
    String? defaultFont,
    String? defaultThemeId,
    String? activeProfileId,
    int? customBackgroundColor,
    int? customTextColor,
    List<AuthorProfile>? profiles,
  }) {
    return CardSettings(
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      avatarPreset: (avatarPreset ?? this.avatarPreset)
          .clamp(0, avatarPresetCount - 1)
          .toInt(),
      avatarPath: avatarPath ?? this.avatarPath,
      defaultFont: defaultFont ?? this.defaultFont,
      defaultThemeId: defaultThemeId ?? this.defaultThemeId,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      customBackgroundColor:
          customBackgroundColor ?? this.customBackgroundColor,
      customTextColor: customTextColor ?? this.customTextColor,
      profiles: profiles ?? this.profiles,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authorName': authorName,
      'authorHandle': authorHandle,
      'avatarPreset': avatarPreset,
      'avatarPath': avatarPath,
      'defaultFont': defaultFont,
      'defaultThemeId': defaultThemeId,
      'activeProfileId': activeProfileId,
      'customBackgroundColor': customBackgroundColor,
      'customTextColor': customTextColor,
    };
  }

  static CardSettings fromMap(Map<dynamic, dynamic> map) {
    final preset = map['avatarPreset'];
    return CardSettings(
      authorName: map['authorName'] as String? ?? '',
      authorHandle: map['authorHandle'] as String? ?? '',
      avatarPreset: preset is int ? preset : 0,
      avatarPath: map['avatarPath'] as String?,
      defaultFont: map['defaultFont'] as String? ?? 'Inter',
      defaultThemeId: map['defaultThemeId'] as String? ?? 'minimal',
      activeProfileId: map['activeProfileId'] as String? ?? '',
      customBackgroundColor: map['customBackgroundColor'] as int? ?? 0xFF0F172A,
      customTextColor: map['customTextColor'] as int? ?? 0xFFF8FAFC,
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
