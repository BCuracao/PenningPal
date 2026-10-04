import 'app_config.dart';

/// Store product metadata. SDK keys and the entitlement id live on [AppConfig]
/// so the dashboard identifiers have a single source of truth.
abstract final class RevenueCatConfig {
  static const String appleApiKey = AppConfig.revenueCatAppleApiKey;
  static const String googleApiKey = AppConfig.revenueCatGoogleApiKey;
  static const String entitlementId = AppConfig.proEntitlementId;
  static const String defaultOfferingId = AppConfig.defaultOfferingId;

  /// One-time non-consumable lifetime unlock ($4.99).
  static const String productId = 'pro_lifetime';

  /// Shown on the paywall CTA when offerings cannot be loaded.
  static const String lifetimePriceLabel = r'$4.99';
}
