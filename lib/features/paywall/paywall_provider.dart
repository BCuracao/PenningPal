import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'paywall_service.dart';

export '../../core/config/app_config.dart'
    show canAccessProFeature, kDemoModeBypassPaywall;

/// Production [PaywallService]. Tests override this with a fake.
final paywallServiceProvider = Provider<PaywallService>(
  (ref) => PaywallService(),
);

/// Async entitlement: `true` when `pro_access` is active.
final paywallProvider =
    AsyncNotifierProvider<PaywallNotifier, bool>(PaywallNotifier.new);

/// Fail-closed reactive flag used by visual lock badges. Loading / error
/// states treat the user as free so Pro chrome stays locked until a real
/// purchase (or restore) lands. Demo bypass must not flip this value.
final isProPurchasedProvider = Provider<bool>((ref) {
  return ref.watch(paywallProvider).value ?? false;
});

/// Action / render gate. True when Pro is purchased **or**
/// [kDemoModeBypassPaywall] is on. Lock icons still read
/// [isProPurchasedProvider].
final canAccessProFeatureProvider = Provider<bool>((ref) {
  return canAccessProFeature(
    isProPurchased: ref.watch(isProPurchasedProvider),
  );
});

class PaywallNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = ref.watch(paywallServiceProvider);
    await service.initialize();
    return service.checkEntitlement();
  }

  /// Runs the lifetime purchase flow and refreshes entitlement on success.
  Future<bool> purchaseLifetime() async {
    final service = ref.read(paywallServiceProvider);
    try {
      final success = await service.purchaseLifetime();
      if (success) {
        state = const AsyncData(true);
        return true;
      }
      return state.value ?? false;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Restores store purchases and refreshes entitlement when Pro is active.
  Future<bool> restorePurchases() async {
    final service = ref.read(paywallServiceProvider);
    try {
      final restored = await service.restorePurchases();
      state = AsyncData(restored);
      return restored;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
