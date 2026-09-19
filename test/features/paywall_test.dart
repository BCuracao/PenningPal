import 'package:clean_canvas/core/config/revenue_cat_config.dart';
import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/templates/card_theme_config.dart';
import 'package:clean_canvas/features/paywall/paywall_bottom_sheet.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('RevenueCatConfig', () {
    test('uses the lifetime product and pro_access entitlement', () {
      expect(RevenueCatConfig.entitlementId, 'pro_access');
      expect(RevenueCatConfig.productId, 'pro_lifetime');
      expect(RevenueCatConfig.lifetimePriceLabel, r'$4.99');
      expect(RevenueCatConfig.appleApiKey, startsWith('appl_'));
      expect(RevenueCatConfig.googleApiKey, startsWith('goog_'));
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

      final unlocked =
          await container.read(paywallProvider.notifier).purchaseLifetime();

      expect(unlocked, isTrue);
      expect(service.purchaseCount, 1);
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
      final unlocked =
          await container.read(paywallProvider.notifier).purchaseLifetime();

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

      expect(find.byKey(const Key('card-watermark')), findsOneWidget);
      expect(find.text(CardLayout.watermarkLabel), findsOneWidget);
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
          child: const MaterialApp(
            home: CardExporterScreen(text: 'A short quote for the card.'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('unentitled theme taps open the paywall and keep Minimal',
        (tester) async {
      await pumpExporter(tester, paywall: FakePaywallService());

      expect(find.byKey(const Key('theme-lock-terminal')), findsOneWidget);
      expect(find.byKey(const Key('theme-lock-midnight')), findsOneWidget);
      expect(find.byKey(const Key('theme-lock-minimal')), findsNothing);
      expect(find.byKey(const Key('card-watermark')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('card-template-terminal')));
      await tester.tap(find.byKey(const Key('card-template-terminal')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
      expect(find.byKey(const Key('terminal-traffic-lights')), findsNothing);
      expect(find.byKey(const Key('paywall-unlock')), findsOneWidget);
      expect(find.byKey(const Key('paywall-restore')), findsOneWidget);
    });

    testWidgets('unentitled watermark toggle opens the paywall', (tester) async {
      await pumpExporter(tester, paywall: FakePaywallService());

      await tester.tap(find.byKey(const Key('remove-watermark-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
      expect(find.byKey(const Key('card-watermark')), findsOneWidget);
    });

    testWidgets('pro users can select Terminal without a lock', (tester) async {
      await pumpExporter(
        tester,
        paywall: FakePaywallService(hasProAccess: true),
      );

      expect(find.byKey(const Key('theme-lock-terminal')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('card-template-terminal')));
      await tester.tap(find.byKey(const Key('card-template-terminal')));
      await tester.pump();

      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
      expect(find.text('Unlock PenningPal Pro'), findsNothing);
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
        find.text(
          'One-time purchase of ${RevenueCatConfig.lifetimePriceLabel} • Lifetime access',
        ),
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
  });
}
