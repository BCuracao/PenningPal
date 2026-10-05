import 'package:penningpal/core/config/app_config.dart';
import 'package:penningpal/core/config/revenue_cat_config.dart';
import 'package:penningpal/features/exporter/presentation/card_canvas.dart';
import 'package:penningpal/features/exporter/presentation/card_exporter_screen.dart';
import 'package:penningpal/features/exporter/templates/card_theme_config.dart';
import 'package:penningpal/features/paywall/paywall_bottom_sheet.dart';
import 'package:penningpal/features/paywall/paywall_provider.dart';
import 'package:penningpal/features/paywall/paywall_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppConfig', () {
    test('ships the Apple key, empty Google key, and strict gating', () {
      expect(AppConfig.revenueCatAppleApiKey, startsWith('appl_'));
      expect(AppConfig.revenueCatAppleApiKey, isNot(contains('YOUR_')));
      expect(AppConfig.revenueCatGoogleApiKey, isEmpty);
      expect(AppConfig.proEntitlementId, 'pro_access');
      expect(AppConfig.defaultOfferingId, 'default');
      expect(AppConfig.kDemoModeBypassPaywall, isFalse);
      expect(kDemoModeBypassPaywall, isFalse);
      expect(RevenueCatConfig.entitlementId, AppConfig.proEntitlementId);
      expect(RevenueCatConfig.productId, 'pro_lifetime');
      expect(RevenueCatConfig.lifetimePriceLabel, r'$4.99');
      expect(RevenueCatConfig.appleApiKey, AppConfig.revenueCatAppleApiKey);
      expect(RevenueCatConfig.googleApiKey, isEmpty);
    });
  });

  group('PaywallNotifier', () {
    test('starts free and becomes pro after a successful purchase', () async {
      final service = FakePaywallService();
      final container = ProviderContainer(
        overrides: [
          paywallServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(paywallProvider.future), isFalse);
      expect(container.read(isProPurchasedProvider), isFalse);
      expect(service.initializeCount, 1);
      expect(service.checkCount, 1);

      final package = sampleLifetimePackage();
      final unlocked = await container
          .read(paywallProvider.notifier)
          .purchasePackage(package);

      expect(unlocked, isTrue);
      expect(service.purchaseCount, 1);
      expect(service.lastPurchasedPackage?.storeProduct.identifier, 'pro_lifetime');
      expect(container.read(paywallProvider).value, isTrue);
      expect(container.read(isProPurchasedProvider), isTrue);
    });

    test('cancelled purchase leaves the user on the free tier', () async {
      final service = FakePaywallService()..purchaseShouldSucceed = false;
      final container = ProviderContainer(
        overrides: [
          paywallServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(paywallProvider.future);
      final unlocked = await container
          .read(paywallProvider.notifier)
          .purchasePackage(sampleLifetimePackage());

      expect(unlocked, isFalse);
      expect(container.read(isProPurchasedProvider), isFalse);
    });

    test('restorePurchases refreshes entitlement when Pro is found', () async {
      final service = FakePaywallService()..restoreGrantsPro = true;
      final container = ProviderContainer(
        overrides: [
          paywallServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(paywallProvider.future), isFalse);

      final restored =
          await container.read(paywallProvider.notifier).restorePurchases();

      expect(restored, isTrue);
      expect(service.restoreCount, 1);
      expect(container.read(isProPurchasedProvider), isTrue);
    });
  });

  group('CardCanvas entitlement gate', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      required bool isProPurchased,
      bool showWatermark = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FittedBox(
              fit: BoxFit.contain,
              child: CardCanvas(
                canvasKey: GlobalKey(),
                text: 'Quote',
                aspectRatio: CardAspectRatio.square,
                theme: CardPresets.minimalClean.copyWith(
                  showWatermark: showWatermark,
                ),
                isProPurchased: isProPurchased,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('unentitled users keep the watermark even if the theme strips it',
        (tester) async {
      await pumpCanvas(
        tester,
        isProPurchased: false,
        showWatermark: false,
      );

      if (canAccessProFeature(isProPurchased: false)) {
        expect(find.byKey(const Key('card-watermark')), findsNothing);
      } else {
        expect(find.byKey(const Key('card-watermark')), findsOneWidget);
        expect(find.text(CardLayout.watermarkLabel), findsOneWidget);
      }
    });

    testWidgets('pro users may hide the watermark', (tester) async {
      await pumpCanvas(
        tester,
        isProPurchased: true,
        showWatermark: false,
      );

      expect(find.byKey(const Key('card-watermark')), findsNothing);
    });
  });

  group('CardExporterScreen gating', () {
    Future<void> pumpExporter(
      WidgetTester tester, {
      required FakePaywallService paywall,
      String text = 'A short quote for the card.',
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(paywall),
          ],
          child: MaterialApp(
            home: CardExporterScreen(text: text),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> openDesign(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('exporter-tab-design')));
      await tester.pumpAndSettle();
    }

    testWidgets('unentitled theme taps open the paywall and keep Minimal',
        (tester) async {
      await pumpExporter(tester, paywall: FakePaywallService());
      await openDesign(tester);

      expect(find.byKey(const Key('theme-lock-terminal')), findsOneWidget);
      expect(find.byKey(const Key('theme-lock-midnight')), findsOneWidget);
      expect(find.byKey(const Key('theme-lock-minimal')), findsNothing);
      final themeScrollable = find.descendant(
        of: find.byKey(const Key('card-template-carousel')),
        matching: find.byType(Scrollable),
      );
      for (final id in ['aurora', 'editorial', 'neo_brutal', 'custom']) {
        final lock = find.byKey(Key('theme-lock-$id'));
        await tester.dragUntilVisible(lock, themeScrollable, const Offset(-160, 0));
        expect(lock, findsOneWidget);
      }
      expect(find.byKey(const Key('card-watermark')), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const Key('card-template-terminal')),
        themeScrollable,
        const Offset(200, 0),
      );
      await tester.tap(find.byKey(const Key('card-template-terminal')));
      await tester.pumpAndSettle();

      if (kDemoModeBypassPaywall) {
        expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
        expect(find.text('Unlock PenningPal Pro'), findsNothing);
      } else {
        expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
        expect(find.byKey(const Key('terminal-traffic-lights')), findsNothing);
        expect(find.byKey(const Key('paywall-unlock')), findsOneWidget);
        expect(find.byKey(const Key('paywall-restore')), findsOneWidget);
      }
    });

    testWidgets('unentitled watermark toggle opens the paywall', (tester) async {
      await pumpExporter(tester, paywall: FakePaywallService());
      await openDesign(tester);

      await tester.tap(find.byKey(const Key('remove-watermark-toggle')));
      await tester.pumpAndSettle();

      if (kDemoModeBypassPaywall) {
        expect(find.text('Unlock PenningPal Pro'), findsNothing);
        expect(find.byKey(const Key('card-watermark')), findsNothing);
      } else {
        expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
        expect(find.byKey(const Key('card-watermark')), findsOneWidget);
      }
    });

    testWidgets('unentitled photo pick and LinkedIn PDF open the paywall',
        (tester) async {
      await pumpExporter(
        tester,
        paywall: FakePaywallService(),
        text: 'Slide one\n\n---\n\nSlide two',
      );
      await openDesign(tester);

      await tester.ensureVisible(find.byKey(const Key('photo-backdrop-choose')));
      await tester.tap(find.byKey(const Key('photo-backdrop-choose')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
      expect(
        find.text('Custom photo backdrops with blur and contrast scrim'),
        findsWidgets,
      );

      Navigator.of(
        tester.element(find.byKey(const Key('paywall-headline'))),
      ).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('export-linkedin-pdf')));
      await tester.tap(find.byKey(const Key('export-linkedin-pdf')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
      expect(
        find.text('Export swipeable LinkedIn PDF carousels'),
        findsWidgets,
      );
    });

    testWidgets('pro users can select Terminal without a lock', (tester) async {
      await pumpExporter(
        tester,
        paywall: FakePaywallService(hasProAccess: true),
      );
      await openDesign(tester);

      expect(find.byKey(const Key('theme-lock-terminal')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('card-template-terminal')));
      await tester.tap(find.byKey(const Key('card-template-terminal')));
      await tester.pump();

      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
      expect(find.text('Unlock PenningPal Pro'), findsNothing);
    });
  });

  group('lifetime package selection', () {
    test('prefers the lifetime slot, then pro_lifetime, else null', () {
      final lifetime = sampleLifetimeOffering(priceString: '€4.99');
      expect(
        selectLifetimePackage(lifetime)?.storeProduct.priceString,
        '€4.99',
      );

      final context = lifetime.lifetime!.presentedOfferingContext;
      final custom = Package(
        'custom',
        PackageType.custom,
        StoreProduct(
          'pro_lifetime',
          'Lifetime',
          'PenningPal Pro Lifetime',
          4.99,
          r'$4.99',
          'USD',
          presentedOfferingContext: context,
        ),
        context,
      );
      final byProduct = Offering(
        'default',
        'Default',
        const <String, Object>{},
        [custom],
      );
      expect(selectLifetimePackage(byProduct)?.identifier, 'custom');
      expect(selectLifetimePackage(null), isNull);
      expect(
        unlockLifetimeButtonLabel(null),
        'Unlock Lifetime Pro — \$4.99',
      );
      expect(
        unlockLifetimeButtonLabel(sampleLifetimePackage(priceString: '€4.99')),
        'Unlock Lifetime Pro — €4.99',
      );
    });
  });

  group('PaywallBottomSheet', () {
    testWidgets('purchase success dismisses the sheet and grants Pro',
        (tester) async {
      final service = FakePaywallService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    key: const Key('open-paywall'),
                    onPressed: () => PaywallBottomSheet.show(context),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('open-paywall')));
      await tester.pumpAndSettle();

      expect(
        find.text('Unlock Lifetime Pro — ${RevenueCatConfig.lifetimePriceLabel}'),
        findsOneWidget,
      );
      expect(
        find.text("Remove 'Made with PenningPal' watermark"),
        findsOneWidget,
      );
      expect(
        find.text('Export swipeable LinkedIn PDF carousels'),
        findsOneWidget,
      );
      expect(
        find.text('Custom photo backdrops with blur and contrast scrim'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('paywall-unlock')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsNothing);
      expect(service.hasProAccess, isTrue);
      expect(service.purchaseCount, 1);
    });

    testWidgets('shows a spinner while the purchase is pending', (tester) async {
      final service = FakePaywallService()
        ..purchaseDelay = const Duration(milliseconds: 80);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    key: const Key('open-paywall'),
                    onPressed: () => PaywallBottomSheet.show(context),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('open-paywall')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paywall-unlock')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Unlock PenningPal Pro'), findsNothing);
    });

    testWidgets('shows the localized store price on the purchase button',
        (tester) async {
      final service = FakePaywallService(priceString: '€4.99');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    key: const Key('open-paywall'),
                    onPressed: () => PaywallBottomSheet.show(context),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-paywall')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Lifetime Pro — €4.99'), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall-unlock')));
      await tester.pumpAndSettle();
      expect(service.lastPurchasedPackage?.storeProduct.priceString, '€4.99');
    });

    testWidgets('offline offerings fall back to \$4.99 without purchasing',
        (tester) async {
      final service = FakePaywallService()..offeringsAvailable = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    key: const Key('open-paywall'),
                    onPressed: () => PaywallBottomSheet.show(context),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-paywall')));
      await tester.pumpAndSettle();

      expect(find.text(r'Unlock Lifetime Pro — $4.99'), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall-unlock')));
      await tester.pumpAndSettle();

      expect(service.purchaseCount, 0);
      expect(find.byKey(const Key('paywall-error')), findsOneWidget);
      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
    });

    testWidgets('a cancelled purchase stays on the sheet without an error',
        (tester) async {
      final service = FakePaywallService()..purchaseShouldSucceed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    key: const Key('open-paywall'),
                    onPressed: () => PaywallBottomSheet.show(context),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-paywall')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paywall-unlock')));
      await tester.pumpAndSettle();

      expect(service.purchaseCount, 1);
      expect(service.hasProAccess, isFalse);
      expect(find.byKey(const Key('paywall-error')), findsNothing);
      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
    });
  });
}
