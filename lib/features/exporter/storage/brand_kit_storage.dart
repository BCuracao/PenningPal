import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/app_config.dart';
import '../models/brand_kit.dart';

/// Thrown when a free account tries to keep more than [BrandKitStorage.freeKitLimit] kits.
class BrandKitLimitException implements Exception {
  const BrandKitLimitException({
    this.message = 'Free accounts can keep 1 brand kit',
  });

  final String message;

  @override
  String toString() => message;
}

/// Local-only Hive wrapper for [BrandKit] documents.
///
/// Free users may keep [freeKitLimit] kit. Pro unlocks unlimited kits.
/// Updating an existing kit is always allowed. When [init] is skipped, an
/// in-memory map is used so unit tests need no plugin binding.
class BrandKitStorage {
  BrandKitStorage();

  BrandKitStorage.withBox(Box<dynamic> box) : _box = box;

  static const String boxName = 'brand_kits_box';
  static const int freeKitLimit = 1;
  static const String _kitsKey = 'kits';

  Box<dynamic>? _box;
  final Map<String, dynamic> _memory = <String, dynamic>{};

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
  }

  List<BrandKit> getAllKits() {
    final raw = _read(_kitsKey);
    if (raw is! List) return <BrandKit>[];
    final kits = <BrandKit>[];
    for (final item in raw) {
      if (item is Map) kits.add(BrandKit.fromMap(item));
    }
    return kits;
  }

  /// True when [kit] may be written for this entitlement.
  ///
  /// An id that is already stored can always be updated. A new id needs Pro
  /// once [freeKitLimit] kits exist.
  bool canSave(BrandKit kit, {required bool isProPurchased}) {
    final existing = getAllKits();
    if (existing.any((item) => item.id == kit.id)) return true;
    if (canAccessProFeature(isProPurchased: isProPurchased)) return true;
    return existing.length < freeKitLimit;
  }

  /// Inserts or replaces [kit]. Free accounts cannot insert a second kit.
  Future<void> saveKit(BrandKit kit, {required bool isProPurchased}) async {
    if (!canSave(kit, isProPurchased: isProPurchased)) {
      throw const BrandKitLimitException();
    }
    final existing = getAllKits();
    final index = existing.indexWhere((item) => item.id == kit.id);
    final next = <BrandKit>[...existing];
    if (index >= 0) {
      next[index] = kit;
    } else {
      next.add(kit);
    }
    await _writeKits(next);
  }

  Future<void> deleteKit(String id) async {
    final next = getAllKits().where((kit) => kit.id != id).toList();
    await _writeKits(next);
  }

  Future<void> _writeKits(List<BrandKit> kits) async {
    final encoded = <Map<String, dynamic>>[
      for (final kit in kits) kit.toMap(),
    ];
    final box = _box;
    if (box != null) {
      await box.put(_kitsKey, encoded);
      return;
    }
    _memory[_kitsKey] = encoded;
  }

  dynamic _read(String key) {
    final box = _box;
    if (box != null) return box.get(key);
    return _memory[key];
  }
}
