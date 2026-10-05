import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/brand_kit.dart';
import '../storage/brand_kit_storage.dart';

final brandKitStorageProvider = Provider<BrandKitStorage>(
  (ref) => BrandKitStorage(),
);

final brandKitsProvider =
    NotifierProvider<BrandKitsNotifier, List<BrandKit>>(BrandKitsNotifier.new);

class BrandKitsNotifier extends Notifier<List<BrandKit>> {
  @override
  List<BrandKit> build() {
    return ref.watch(brandKitStorageProvider).getAllKits();
  }

  /// Returns false when the free-tier cap blocks a new kit.
  Future<bool> saveKit(
    BrandKit kit, {
    required bool isProPurchased,
  }) async {
    final storage = ref.read(brandKitStorageProvider);
    try {
      await storage.saveKit(kit, isProPurchased: isProPurchased);
    } on BrandKitLimitException {
      return false;
    }
    state = storage.getAllKits();
    return true;
  }

  Future<void> deleteKit(String id) async {
    final storage = ref.read(brandKitStorageProvider);
    await storage.deleteKit(id);
    state = storage.getAllKits();
  }
}
