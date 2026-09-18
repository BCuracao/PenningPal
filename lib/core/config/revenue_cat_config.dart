/// Public RevenueCat identifiers and store product metadata.
///
/// Replace the placeholder API keys with the iOS / Android public SDK keys
/// from the RevenueCat dashboard before shipping. Entitlement and product
/// IDs must match the dashboard configuration exactly.
abstract final class RevenueCatConfig {
  /// iOS / Apple public SDK key (`appl_…`).
  static const String appleApiKey = 'appl_YOUR_REVENUECAT_APPLE_API_KEY';

  /// Android / Google Play public SDK key (`goog_…`).
  static const String googleApiKey = 'goog_YOUR_REVENUECAT_GOOGLE_API_KEY';

  /// Entitlement that unlocks Pro themes and watermark removal.
  static const String entitlementId = 'pro_access';

  /// One-time non-consumable lifetime unlock ($4.99).
  static const String productId = 'pro_lifetime';

  static const String lifetimePriceLabel = r'$4.99';
}
