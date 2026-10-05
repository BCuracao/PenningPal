import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:penningpal/features/exporter/models/brand_kit.dart';
import 'package:penningpal/features/exporter/models/font_pairing.dart';
import 'package:penningpal/features/exporter/presentation/card_exporter_screen.dart';
import 'package:penningpal/features/exporter/presentation/widgets/cta_qr_code_widget.dart';
import 'package:penningpal/features/exporter/state/brand_kit_notifier.dart';
import 'package:penningpal/features/exporter/storage/brand_kit_storage.dart';
import 'package:penningpal/features/exporter/templates/card_theme_config.dart';
import 'package:penningpal/features/paywall/paywall_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FontPairings', () {
    test('ships four presets and keeps three of them on Pro', () {
      expect(FontPairings.all, hasLength(4));
      expect(FontPairings.modernTech.isPro, isFalse);
      expect(FontPairings.editorialAuthority.isPro, isTrue);
      expect(FontPairings.highImpact.isPro, isTrue);
      expect(FontPairings.minimalist.isPro, isTrue);
      expect(FontPairings.modernTech.headerFamily, 'Inter');
      expect(FontPairings.modernTech.bodyFamily, 'JetBrains Mono');
      expect(FontPairings.editorialAuthority.headerFamily, 'Playfair Display');
      expect(FontPairings.highImpact.bodyFamily, 'Open Sans');
      expect(FontPairings.minimalist.bodyFamily, 'DM Sans');
    });

    test('High Impact headlines stay bold', () {
      final style = FontPairings.highImpact.headerFont(
        fontWeight: FontWeight.w400,
      );
      expect(style.fontWeight, FontWeight.w700);

      final heavier = FontPairings.highImpact.applyHeader(
        const TextStyle(fontWeight: FontWeight.w800, fontSize: 40),
      );
      expect(heavier.fontWeight, FontWeight.w800);
    });

    test('free users cannot resolve a Pro pairing', () {
      expect(
        FontPairings.resolve('modern_tech', isProPurchased: false)?.id,
        'modern_tech',
      );
      final editorial = FontPairings.resolve(
        'editorial_authority',
        isProPurchased: false,
      );
      if (canAccessProFeature(isProPurchased: false)) {
        expect(editorial?.id, 'editorial_authority');
      } else {
        expect(editorial, isNull);
      }
      expect(
        FontPairings.resolve('editorial_authority', isProPurchased: true)?.id,
        'editorial_authority',
      );
      expect(FontPairings.resolve('missing', isProPurchased: true), isNull);
    });
  });

  group('BrandKit serialization', () {
    test('round-trips palette, type, logo, and aspect ratio', () {
      final kit = BrandKit(
        id: 'kit_1',
        name: '  Company  ',
        primaryColor: '#4f46e5',
        secondaryColor: 'fff',
        fontPairingId: 'editorial_authority',
        logoPath: '/tmp/logo.png',
        aspectRatio: CardAspectRatio.story,
      );

      expect(kit.name, 'Company');
      expect(kit.primaryColor, '#4F46E5');
      expect(kit.secondaryColor, '#FFFFFF');

      final restored = BrandKit.fromMap(kit.toMap());
      expect(restored, kit);
      expect(restored.aspectRatio, CardAspectRatio.story);
      expect(restored.logoPath, '/tmp/logo.png');
      expect(restored.fontPairingId, 'editorial_authority');
    });

    test('falls back when hex, name, logo, or ratio are unusable', () {
      final kit = BrandKit(
        id: 'kit_bad',
        name: '   ',
        primaryColor: 'nope',
        secondaryColor: '#zzzzzz',
        fontPairingId: 'modern_tech',
        logoPath: '   ',
      );
      expect(kit.name, 'Personal Brand');
      expect(kit.primaryColor, '#0F172A');
      expect(kit.secondaryColor, '#F8FAFC');
      expect(kit.logoPath, isNull);

      final restored = BrandKit.fromMap(<String, dynamic>{
        'id': 'kit_map',
        'aspectRatio': 'portrait',
        'logoPath': '',
      });
      expect(restored.aspectRatio, CardAspectRatio.square);
      expect(restored.logoPath, isNull);
      expect(restored.fontPairingId, 'modern_tech');
    });
  });

  group('BrandKitStorage limits', () {
    BrandKit kit(String id, {String name = 'Personal Brand'}) {
      return BrandKit(
        id: id,
        name: name,
        primaryColor: '#111827',
        secondaryColor: '#F9FAFB',
        fontPairingId: FontPairings.modernTech.id,
      );
    }

    test('free users can save one kit and are blocked on the second', () async {
      final storage = BrandKitStorage();
      expect(
        storage.canSave(kit('a'), isProPurchased: false),
        isTrue,
      );

      await storage.saveKit(kit('a', name: 'Personal'), isProPurchased: false);
      expect(storage.getAllKits(), hasLength(1));

      final renamed = kit('a', name: 'Personal Brand');
      await storage.saveKit(renamed, isProPurchased: false);
      expect(storage.getAllKits().single.name, 'Personal Brand');

      if (canAccessProFeature(isProPurchased: false)) {
        await storage.saveKit(kit('b', name: 'Company'), isProPurchased: false);
        expect(storage.getAllKits(), hasLength(2));
      } else {
        expect(storage.canSave(kit('b'), isProPurchased: false), isFalse);
        expect(
          () => storage.saveKit(kit('b'), isProPurchased: false),
          throwsA(isA<BrandKitLimitException>()),
        );
        expect(storage.getAllKits(), hasLength(1));
      }
    });

    test('pro users can save and delete multiple kits', () async {
      final storage = BrandKitStorage();
      await storage.saveKit(kit('a', name: 'Personal'), isProPurchased: true);
      await storage.saveKit(kit('b', name: 'Company'), isProPurchased: true);
      expect(storage.getAllKits(), hasLength(2));
      expect(storage.canSave(kit('c'), isProPurchased: true), isTrue);

      await storage.deleteKit('a');
      expect(storage.getAllKits().map((item) => item.id), ['b']);
    });

    test('Hive box round-trips the kit list', () async {
      final dir = await Directory.systemTemp.createTemp('penningpal_brand_kits_');
      Hive.init(dir.path);
      final boxName = 'brand_kits_box_${dir.hashCode}';
      final box = await Hive.openBox<dynamic>(boxName);
      addTearDown(() async {
        if (box.isOpen) await box.close();
        await Hive.deleteBoxFromDisk(boxName);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final storage = BrandKitStorage.withBox(box);
      await storage.saveKit(
        kit('saved', name: 'Company'),
        isProPurchased: true,
      );

      final reloaded = BrandKitStorage.withBox(box);
      final kits = reloaded.getAllKits();
      expect(kits, hasLength(1));
      expect(kits.single.name, 'Company');
      expect(kits.single.primaryColor, '#111827');
    });

    test('notifier refuses a second free kit', () async {
      final storage = BrandKitStorage();
      final container = ProviderContainer(
        overrides: [
          brandKitStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(brandKitsProvider.notifier);
      final first = await notifier.saveKit(
        kit('one'),
        isProPurchased: false,
      );
      expect(first, isTrue);
      expect(container.read(brandKitsProvider), hasLength(1));

      final second = await notifier.saveKit(
        kit('two'),
        isProPurchased: false,
      );
      if (canAccessProFeature(isProPurchased: false)) {
        expect(second, isTrue);
      } else {
        expect(second, isFalse);
        expect(container.read(brandKitsProvider), hasLength(1));
      }
    });
  });

  group('CTA QR destinations', () {
    test('accepts http(s) links and bare domains', () {
      expect(
        CtaQrDestination.normalize('https://linkedin.com/in/ada'),
        'https://linkedin.com/in/ada',
      );
      expect(
        CtaQrDestination.normalize('  http://example.com/news  '),
        'http://example.com/news',
      );
      expect(
        CtaQrDestination.payloadFor('linkedin.com/in/ada'),
        'https://linkedin.com/in/ada',
      );
      expect(
        CtaQrDestination.payloadFor('www.example.com/newsletter?id=1'),
        'https://www.example.com/newsletter?id=1',
      );
    });

    test('rejects empty, spaced, and non-http strings', () {
      expect(CtaQrDestination.normalize(null), isNull);
      expect(CtaQrDestination.normalize('   '), isNull);
      expect(CtaQrDestination.normalize('not a url'), isNull);
      expect(CtaQrDestination.normalize('notaurl'), isNull);
      expect(CtaQrDestination.normalize('javascript:alert(1)'), isNull);
      expect(CtaQrDestination.normalize('ftp://files.example.com'), isNull);
      expect(CtaQrDestination.payloadFor(''), isNull);
      expect(
        CtaQrDestination.payloadFor('https://example.com/${'a' * 1200}'),
        isNull,
      );
    });

    testWidgets('invalid strings render the fallback instead of a QR image', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CtaQrCodeWidget(
              destination: 'not a url',
              foregroundColor: Color(0xFF111827),
              accentColor: Color(0xFFF59E0B),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cta-qr-fallback')), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('a valid link renders QrImageView in the theme colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CtaQrCodeWidget(
              destination: 'https://penningpal.app/pro',
              foregroundColor: Color(0xFFF8FAFC),
              accentColor: Color(0xFF818CF8),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cta-qr-image')), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('cta-qr-fallback')), findsNothing);

      final plate = ctaQrPlateColor(
        foreground: const Color(0xFFF8FAFC),
        accent: const Color(0xFF818CF8),
      );
      expect(plate.computeLuminance(), lessThan(0.4));
    });
  });

  group('Card exporter gating', () {
    Future<void> pumpExporter(
      WidgetTester tester, {
      required BrandKitStorage kits,
      bool pro = false,
    }) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: pro),
            ),
            brandKitStorageProvider.overrideWithValue(kits),
          ],
          child: const MaterialApp(
            home: CardExporterScreen(text: 'A short quote for the card.'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('tapping a Pro font pairing opens the paywall', (tester) async {
      await pumpExporter(tester, kits: BrandKitStorage());
      await tester.tap(find.byKey(const Key('exporter-tab-design')));
      await tester.pumpAndSettle();

      final chip = find.byKey(const Key('font-pairing-editorial_authority'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      if (kDemoModeBypassPaywall) {
        expect(find.text('Unlock PenningPal Pro'), findsNothing);
      } else {
        expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
        expect(find.text('Editorial Authority font pairing'), findsOneWidget);
      }
    });

    testWidgets('saving a second brand kit opens the paywall', (tester) async {
      final kits = BrandKitStorage();
      await kits.saveKit(
        BrandKit(
          id: 'kit_existing',
          name: 'Personal Brand',
          primaryColor: '#0F172A',
          secondaryColor: '#F8FAFC',
          fontPairingId: 'modern_tech',
        ),
        isProPurchased: true,
      );
      await pumpExporter(tester, kits: kits);
      await tester.tap(find.byKey(const Key('exporter-tab-design')));
      await tester.pumpAndSettle();

      final save = find.byKey(const Key('brand-kit-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      if (canAccessProFeature(isProPurchased: false)) {
        expect(find.byKey(const Key('brand-kit-save-sheet')), findsOneWidget);
      } else {
        expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
        expect(find.text('Free accounts can save 1 brand kit'), findsOneWidget);
        expect(find.byKey(const Key('brand-kit-save-sheet')), findsNothing);
      }
    });

    testWidgets('CTA slides show a QR code for a valid destination', (
      tester,
    ) async {
      await pumpExporter(tester, kits: BrandKitStorage(), pro: true);

      await tester.tap(find.byKey(const Key('slide-role-cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cta-qr-panel')), findsOneWidget);
      final toggle = find.byKey(const Key('cta-qr-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      expect(find.byKey(const Key('cta-qr-fallback')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('cta-qr-url')),
        'not a url',
      );
      await tester.pump();
      expect(find.byKey(const Key('cta-qr-invalid')), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.enterText(
        find.byKey(const Key('cta-qr-url')),
        'https://linkedin.com/in/ada',
      );
      await tester.pump();

      expect(find.byKey(const Key('cta-qr-image')), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('cta-qr-fallback')), findsNothing);
    });
  });
}
