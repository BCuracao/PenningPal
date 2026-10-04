/// Production RevenueCat identifiers and the paywall enforcement switch.
///
/// [revenueCatAppleApiKey] and [revenueCatGoogleApiKey] are public SDK keys
/// (safe to ship in the client). The Google key stays empty until a Play
/// Console app is linked in the RevenueCat dashboard.
abstract final class AppConfig {
  static const String revenueCatAppleApiKey = 'appl_HfdhYapkkajmtkTUUYSOXeNvZFo';
  static const String revenueCatGoogleApiKey = '';
  static const String proEntitlementId = 'pro_access';
  static const String defaultOfferingId = 'default';

  /// Enforce production gating. Set to true only for demos and recordings.
  static const bool kDemoModeBypassPaywall = false;
}

/// Alias so existing call sites can keep reading the top-level flag.
const bool kDemoModeBypassPaywall = AppConfig.kDemoModeBypassPaywall;

/// Action / render gate. Visual lock badges read [isProPurchased] directly;
/// intercepts and watermark enforcement should use this helper.
bool canAccessProFeature({required bool isProPurchased}) {
  return kDemoModeBypassPaywall || isProPurchased;
}
