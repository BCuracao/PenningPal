import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/revenue_cat_config.dart';

/// RevenueCat-backed lifetime unlock. Methods are instance-based so tests
/// can substitute a fake without hitting StoreKit / Play Billing.
class PaywallService {
  bool _didConfigure = false;

  /// Configures the SDK with the platform public key and enables debug logs
  /// in debug builds. Safe to call more than once; later calls no-op after a
  /// successful configure. Failures (missing plugin, desktop, test harness)
  /// leave the user on the free tier.
  Future<void> initialize() async {
    if (_didConfigure) return;
    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(
        PurchasesConfiguration(_apiKeyForPlatform()),
      );
      _didConfigure = true;
    } on MissingPluginException {
      _didConfigure = false;
    } on PlatformException {
      _didConfigure = false;
    } catch (_) {
      _didConfigure = false;
    }
  }

  /// Reads cached [CustomerInfo] so offline users keep Pro after purchase.
  Future<bool> checkEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return _hasProAccess(info);
    } catch (_) {
      return false;
    }
  }

  /// Purchases the `pro_lifetime` non-consumable. Returns `true` when the
  /// `pro_access` entitlement is active afterwards. User-cancelled sheets
  /// return `false` without throwing.
  Future<bool> purchaseLifetime() async {
    try {
      // Android requires [PurchaseType.inapp] for non-consumables; the
      // default looks up a subscription SKU and would miss `pro_lifetime`.
      // ignore: deprecated_member_use
      final result = await Purchases.purchaseProduct(
        RevenueCatConfig.productId,
        // ignore: deprecated_member_use
        type: PurchaseType.inapp,
      );
      return _hasProAccess(result.customerInfo);
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

  /// App Store / Play restore path. Returns whether `pro_access` is active
  /// on the restored [CustomerInfo].
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return _hasProAccess(info);
    } catch (_) {
      return false;
    }
  }

  String _apiKeyForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return RevenueCatConfig.appleApiKey;
      default:
        return RevenueCatConfig.googleApiKey;
    }
  }

  bool _hasProAccess(CustomerInfo info) {
    return info.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ??
        false;
  }
}
