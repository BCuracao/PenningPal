import 'package:clean_canvas/features/paywall/paywall_service.dart';

/// In-memory [PaywallService] for unit and widget tests.
class FakePaywallService implements PaywallService {
  FakePaywallService({this.hasProAccess = false});

  bool hasProAccess;
  bool purchaseShouldSucceed = true;
  bool restoreGrantsPro = false;
  Duration purchaseDelay = Duration.zero;
  Duration restoreDelay = Duration.zero;

  int initializeCount = 0;
  int checkCount = 0;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
  }

  @override
  Future<bool> checkEntitlement() async {
    checkCount += 1;
    return hasProAccess;
  }

  @override
  Future<bool> purchaseLifetime() async {
    purchaseCount += 1;
    if (purchaseDelay > Duration.zero) {
      await Future<void>.delayed(purchaseDelay);
    }
    if (purchaseShouldSucceed) {
      hasProAccess = true;
      return true;
    }
    return false;
  }

  @override
  Future<bool> restorePurchases() async {
    restoreCount += 1;
    if (restoreDelay > Duration.zero) {
      await Future<void>.delayed(restoreDelay);
    }
    if (restoreGrantsPro) {
      hasProAccess = true;
    }
    return hasProAccess;
  }
}
