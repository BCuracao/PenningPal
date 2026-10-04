import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/revenue_cat_config.dart';

/// Picks the lifetime package from an offering. Prefers RevenueCat's lifetime
/// slot, then a package whose store product is `pro_lifetime`, then a sole
/// package when the offering only contains the lifetime unlock.
Package? selectLifetimePackage(Offering? offering) {
  if (offering == null) return null;
  final lifetime = offering.lifetime;
  if (lifetime != null) return lifetime;
  for (final package in offering.availablePackages) {
    if (package.packageType == PackageType.lifetime) return package;
    if (package.storeProduct.identifier == RevenueCatConfig.productId) {
      return package;
    }
  }
  if (offering.availablePackages.length == 1) {
    return offering.availablePackages.first;
  }
  return null;
}

/// RevenueCat-backed lifetime unlock. Methods are instance-based so tests
/// can substitute a fake without hitting StoreKit / Play Billing.
class PaywallService {
  bool _didConfigure = false;

  /// Configures the SDK with the platform public key, StoreKit 2 on Apple
  /// platforms, and debug logs. Safe to call more than once. Failures
  /// (missing plugin, empty Google key, desktop, test harness) leave the
  /// user on the free tier.
  Future<void> initialize() async {
    if (_didConfigure) return;
    final apiKey = _apiKeyForPlatform();
    if (apiKey.isEmpty) return;
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final configuration = PurchasesConfiguration(apiKey)
        ..storeKitVersion = StoreKitVersion.storeKit2;
      await Purchases.configure(configuration);
      _didConfigure = true;
    } on MissingPluginException {
      _didConfigure = false;
    } on PlatformException {
      _didConfigure = false;
    } catch (_) {
      _didConfigure = false;
    }
  }

  /// Active offering from the RevenueCat dashboard. Falls back to the
  /// offering id [AppConfig.defaultOfferingId] when `current` is unset.
  /// Returns null when the store or network is unavailable.
  Future<Offering?> fetchCurrentOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current ??
          offerings.getOffering(AppConfig.defaultOfferingId);
    } catch (_) {
      return null;
    }
  }

  /// Reads cached [CustomerInfo] so offline users keep Pro after purchase.
  Future<bool> checkEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return hasProAccess(info);
    } catch (_) {
      return false;
    }
  }

  /// Purchases [package]. Returns `true` when `pro_access` is active.
  /// A user-cancelled sheet returns `false` and does not throw, so the
  /// paywall can dismiss the attempt without an error alert.
  Future<bool> purchasePackage(Package package) async {
    try {
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      return hasProAccess(result.customerInfo);
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  /// App Store / Play restore path. Returns whether `pro_access` is active.
  /// Cancellation and store failures return `false` instead of throwing.
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return hasProAccess(info);
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool hasProAccess(CustomerInfo info) {
    return info.entitlements.all[AppConfig.proEntitlementId]?.isActive == true;
  }

  String _apiKeyForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppConfig.revenueCatAppleApiKey;
      case TargetPlatform.android:
        return AppConfig.revenueCatGoogleApiKey;
      default:
        return '';
    }
  }
}
