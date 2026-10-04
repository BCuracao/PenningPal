import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_config.dart';
import '../services/paywall_service.dart';

export '../../../core/config/app_config.dart'
    show canAccessProFeature, kDemoModeBypassPaywall;

/// Production [PaywallService]. Tests override this with a fake.
final paywallServiceProvider = Provider<PaywallService>(
  (ref) => PaywallService(),
);

/// Async entitlement: `true` when `pro_access` is active.
final paywallProvider =
    AsyncNotifierProvider<PaywallNotifier, bool>(PaywallNotifier.new);

/// Reactive Pro flag. True when [AppConfig.kDemoModeBypassPaywall] is on or
/// the `pro_access` entitlement is active. Stays in sync with StoreKit / Play
/// via [Purchases.addCustomerInfoUpdateListener] registered by [PaywallNotifier].
final isProPurchasedProvider = Provider<bool>((ref) {
  if (AppConfig.kDemoModeBypassPaywall) return true;
  return ref.watch(paywallProvider).value ?? false;
});

/// Localized offering used by the paywall CTA. Null when offline.
final currentOfferingProvider = FutureProvider<Offering?>((ref) async {
  final service = ref.watch(paywallServiceProvider);
  await service.initialize();
  return service.fetchCurrentOffering();
});

/// Action / render gate. True when Pro is purchased **or**
/// [kDemoModeBypassPaywall] is on.
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
    _listenForCustomerInfo();
    if (AppConfig.kDemoModeBypassPaywall) return true;
    return service.checkEntitlement();
  }

  /// Purchases [package] and refreshes entitlement when Pro becomes active.
  /// Cancellation returns `false` without an error state.
  Future<bool> purchasePackage(Package package) async {
    final service = ref.read(paywallServiceProvider);
    final success = await service.purchasePackage(package);
    if (success) {
      state = const AsyncData(true);
    }
    return success;
  }

  /// Restores store purchases and refreshes entitlement when Pro is active.
  Future<bool> restorePurchases() async {
    final service = ref.read(paywallServiceProvider);
    try {
      final restored = await service.restorePurchases();
      state = AsyncData(AppConfig.kDemoModeBypassPaywall || restored);
      return restored;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void _listenForCustomerInfo() {
    void onCustomerInfo(CustomerInfo info) {
      final next = AppConfig.kDemoModeBypassPaywall ||
          PaywallService.hasProAccess(info);
      scheduleMicrotask(() {
        if (!ref.mounted) return;
        state = AsyncData(next);
      });
    }

    Purchases.addCustomerInfoUpdateListener(onCustomerInfo);
    ref.onDispose(() {
      Purchases.removeCustomerInfoUpdateListener(onCustomerInfo);
    });
  }
}
