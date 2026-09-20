/// Set to true during demos, video recordings, and testing to unlock
/// all features without completing StoreKit/Play Billing transactions.
/// Set to false before App Store / Google Play production submission.
/// Turning this back to `false` restores strict paywall enforcement
/// with no further refactoring.
const bool kDemoModeBypassPaywall = true;

/// Action / render gate. Visual lock badges must still read the raw
/// purchase flag; only intercepts and watermark enforcement should use
/// this helper.
bool canAccessProFeature({required bool isProPurchased}) {
  return kDemoModeBypassPaywall || isProPurchased;
}
