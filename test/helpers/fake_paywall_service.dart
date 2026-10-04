import 'package:penningpal/core/config/app_config.dart';
import 'package:penningpal/features/paywall/paywall_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// In-memory [PaywallService] for unit and widget tests.
class FakePaywallService implements PaywallService {
  FakePaywallService({
    this.hasProAccess = false,
    this.offeringsAvailable = true,
    this.priceString = r'$4.99',
  });

  bool hasProAccess;
  bool purchaseShouldSucceed = true;
  bool restoreGrantsPro = false;
  bool offeringsAvailable;
  String priceString;
  Duration purchaseDelay = Duration.zero;
  Duration restoreDelay = Duration.zero;

  int initializeCount = 0;
  int checkCount = 0;
  int purchaseCount = 0;
  int restoreCount = 0;
  int offeringFetchCount = 0;
  Package? lastPurchasedPackage;

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
  Future<Offering?> fetchCurrentOffering() async {
    offeringFetchCount += 1;
    if (!offeringsAvailable) return null;
    return sampleLifetimeOffering(priceString: priceString);
  }

  @override
  Future<bool> purchasePackage(Package package) async {
    purchaseCount += 1;
    lastPurchasedPackage = package;
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

Package sampleLifetimePackage({String priceString = r'$4.99'}) {
  const context = PresentedOfferingContext(
    AppConfig.defaultOfferingId,
    null,
    null,
  );
  return Package(
    r'$rc_lifetime',
    PackageType.lifetime,
    StoreProduct(
      'pro_lifetime',
      'Lifetime access to PenningPal Pro.',
      'PenningPal Pro Lifetime',
      4.99,
      priceString,
      'USD',
      presentedOfferingContext: context,
    ),
    context,
  );
}

Offering sampleLifetimeOffering({String priceString = r'$4.99'}) {
  final package = sampleLifetimePackage(priceString: priceString);
  return Offering(
    AppConfig.defaultOfferingId,
    'Default',
    const <String, Object>{},
    [package],
    lifetime: package,
  );
}
