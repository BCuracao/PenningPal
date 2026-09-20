import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

/// Ghostwriter / brand persona stored in the `profiles_box` Hive box.
class AuthorProfile {
  const AuthorProfile({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarPath,
    this.defaultFont = 'Inter',
    this.defaultThemeId = 'minimal',
    this.avatarPreset = 0,
  });

  static const String untitled = 'My Brand';

  final String id;
  final String name;
  final String handle;
  final String? avatarPath;
  final String defaultFont;
  final String defaultThemeId;
  final int avatarPreset;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final handleLabel = formattedHandle;
    if (handleLabel != null) return handleLabel;
    return untitled;
  }

  String? get formattedHandle {
    final value = handle.trim();
    if (value.isEmpty) return null;
    return value.startsWith('@') ? value : '@$value';
  }

  String get initials {
    final source = name.trim().isNotEmpty
        ? name.trim()
        : handle.trim().replaceFirst(RegExp(r'^@'), '');
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

  AuthorProfile copyWith({
    String? id,
    String? name,
    String? handle,
    String? avatarPath,
    String? defaultFont,
    String? defaultThemeId,
    int? avatarPreset,
  }) {
    return AuthorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarPath: avatarPath ?? this.avatarPath,
      defaultFont: defaultFont ?? this.defaultFont,
      defaultThemeId: defaultThemeId ?? this.defaultThemeId,
      avatarPreset: (avatarPreset ?? this.avatarPreset).clamp(0, 5).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'handle': handle,
      'avatarPath': avatarPath,
      'defaultFont': defaultFont,
      'defaultThemeId': defaultThemeId,
      'avatarPreset': avatarPreset,
    };
  }

  static AuthorProfile fromMap(Map<dynamic, dynamic> map, {String? fallbackId}) {
    final preset = map['avatarPreset'];
    return AuthorProfile(
      id: map['id'] as String? ?? fallbackId ?? generateProfileId(),
      name: map['name'] as String? ?? '',
      handle: map['handle'] as String? ?? '',
      avatarPath: map['avatarPath'] as String?,
      defaultFont: map['defaultFont'] as String? ?? 'Inter',
      defaultThemeId: map['defaultThemeId'] as String? ?? 'minimal',
      avatarPreset: preset is int ? preset : 0,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthorProfile &&
        other.id == id &&
        other.name == name &&
        other.handle == handle &&
        other.avatarPath == avatarPath &&
        other.defaultFont == defaultFont &&
        other.defaultThemeId == defaultThemeId &&
        other.avatarPreset == avatarPreset;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        handle,
        avatarPath,
        defaultFont,
        defaultThemeId,
        avatarPreset,
      );
}

/// Thrown when a free account tries to create more than [ProfileStorage.freeProfileLimit] personas.
class ProfileLimitException implements Exception {
  const ProfileLimitException({
    this.message = 'Free accounts can keep 1 brand profile',
  });

  final String message;

  @override
  String toString() => message;
}

final Random _profileIdRandom = Random();

String generateProfileId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final entropy = _profileIdRandom.nextInt(0x7fffffff).toRadixString(16);
  return 'p_${now}_$entropy';
}

/// Local-only Hive wrapper for ghostwriter / brand profiles.
///
/// Free users may keep [freeProfileLimit] profile. Pro unlocks unlimited
/// personas. When [init] is skipped, an in-memory map is used (unit tests).
class ProfileStorage {
  ProfileStorage();

  ProfileStorage.withBox(Box<dynamic> box) : _box = box;

  static const String boxName = 'profiles_box';
  static const int freeProfileLimit = 1;

  static const String _activeIdKey = '__active_id__';
  static const String _profileKeyPrefix = 'profile:';

  Box<dynamic>? _box;
  final Map<String, dynamic> _memory = <String, dynamic>{};

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
  }

  List<AuthorProfile> listProfiles() {
    final profiles = <AuthorProfile>[];
    for (final key in _allKeys) {
      if (!key.startsWith(_profileKeyPrefix)) continue;
      final profile = _decode(
        _read(key),
        fallbackId: key.substring(_profileKeyPrefix.length),
      );
      if (profile != null) profiles.add(profile);
    }
    profiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return profiles;
  }

  AuthorProfile? getProfile(String id) => _decode(_read(_profileKey(id)), fallbackId: id);

  String? getActiveId() => _read(_activeIdKey) as String?;

  AuthorProfile? getActiveProfile() {
    final id = getActiveId();
    if (id != null) {
      final active = getProfile(id);
      if (active != null) return active;
    }
    final all = listProfiles();
    return all.isEmpty ? null : all.first;
  }

  Future<void> setActiveId(String id) async {
    await _write(_activeIdKey, id);
  }

  bool canAddProfile({required bool isProPurchased}) {
    if (canAccessProFeature(isProPurchased: isProPurchased)) return true;
    return listProfiles().length < freeProfileLimit;
  }

  /// Creates a persona. Free accounts are capped at [freeProfileLimit].
  Future<AuthorProfile> createProfile({
    required bool isProPurchased,
    String name = '',
    String handle = '',
    String? avatarPath,
    String defaultFont = 'Inter',
    String defaultThemeId = 'minimal',
    int avatarPreset = 0,
  }) async {
    if (!canAddProfile(isProPurchased: isProPurchased)) {
      throw const ProfileLimitException();
    }
    final profile = AuthorProfile(
      id: generateProfileId(),
      name: name,
      handle: handle,
      avatarPath: avatarPath,
      defaultFont: defaultFont,
      defaultThemeId: defaultThemeId,
      avatarPreset: avatarPreset,
    );
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(AuthorProfile profile) async {
    await _write(_profileKey(profile.id), profile.toMap());
  }

  Future<void> deleteProfile(String id) async {
    final remaining = listProfiles().where((profile) => profile.id != id).toList();
    if (remaining.isEmpty) {
      return;
    }
    await _delete(_profileKey(id));
    if (getActiveId() == id) {
      await _write(_activeIdKey, remaining.first.id);
    }
  }

  /// First launch: lift the single saved author into a real profile.
  void seedFrom({
    String authorName = '',
    String authorHandle = '',
    String? avatarPath,
    String defaultFont = 'Inter',
    String defaultThemeId = 'minimal',
    int avatarPreset = 0,
  }) {
    if (listProfiles().isNotEmpty) return;
    final profile = AuthorProfile(
      id: generateProfileId(),
      name: authorName,
      handle: authorHandle,
      avatarPath: avatarPath,
      defaultFont: defaultFont,
      defaultThemeId: defaultThemeId,
      avatarPreset: avatarPreset,
    );
    _writeSync(_profileKey(profile.id), profile.toMap());
    _writeSync(_activeIdKey, profile.id);
  }

  String _profileKey(String id) => '$_profileKeyPrefix$id';

  AuthorProfile? _decode(dynamic value, {String? fallbackId}) {
    if (value is Map) {
      return AuthorProfile.fromMap(value, fallbackId: fallbackId);
    }
    return null;
  }

  Iterable<String> get _allKeys {
    final box = _box;
    if (box != null) {
      return box.keys.map((key) => key.toString());
    }
    return _memory.keys;
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
    final box = _box;
    if (box != null) {
      await box.delete(key);
      return;
    }
    _memory.remove(key);
  }
}
