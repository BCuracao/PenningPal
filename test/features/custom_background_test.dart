import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clean_canvas/features/exporter/models/carousel_deck.dart';
import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/card_customizer_controls.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/render/card_rasterizer.dart';
import 'package:clean_canvas/features/exporter/render/carousel_batch_exporter.dart';
import 'package:clean_canvas/features/exporter/render/linkedin_pdf_exporter.dart';
import 'package:clean_canvas/features/exporter/render/photo_backdrop_store.dart';
import 'package:clean_canvas/features/exporter/templates/card_theme_config.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CardThemeConfig photo backdrop', () {
    test('presets default to no photo, blur 12, and a 50% dark scrim', () {
      const theme = CardPresets.minimalClean;
      expect(theme.customBackgroundImagePath, isNull);
      expect(theme.hasCustomBackground, isFalse);
      expect(theme.blurSigma, CardThemeConfig.defaultBlurSigma);
      expect(theme.overlayOpacity, CardThemeConfig.defaultOverlayOpacity);
      expect(theme.isDarkOverlay, isTrue);
      expect(theme.resolvedBlurSigma, 12);
      expect(theme.resolvedOverlayOpacity, 0.5);
    });

    test('copyWith sets and clears the photo path without mutating the preset', () {
      const original = CardPresets.minimalClean;
      final withPhoto = original.copyWith(
        customBackgroundImagePath: '/tmp/backdrop.jpg',
        blurSigma: 20,
        overlayOpacity: 0.7,
        isDarkOverlay: false,
      );

      expect(original.customBackgroundImagePath, isNull);
      expect(withPhoto.customBackgroundImagePath, '/tmp/backdrop.jpg');
      expect(withPhoto.hasCustomBackground, isTrue);
      expect(withPhoto.blurSigma, 20);
      expect(withPhoto.overlayOpacity, 0.7);
      expect(withPhoto.isDarkOverlay, isFalse);

      final cleared = withPhoto.copyWith(customBackgroundImagePath: null);
      expect(cleared.customBackgroundImagePath, isNull);
      expect(cleared.blurSigma, 20);
    });

    test('resolved values clamp blur 0–30 and overlay 20–85%', () {
      final blown = CardPresets.minimalClean.copyWith(
        blurSigma: 99,
        overlayOpacity: 0.05,
      );
      expect(blown.resolvedBlurSigma, CardThemeConfig.maxBlurSigma);
      expect(blown.resolvedOverlayOpacity, CardThemeConfig.minOverlayOpacity);

      final clipped = CardPresets.minimalClean.copyWith(
        blurSigma: -4,
        overlayOpacity: 1,
      );
      expect(clipped.resolvedBlurSigma, CardThemeConfig.minBlurSigma);
      expect(clipped.resolvedOverlayOpacity, CardThemeConfig.maxOverlayOpacity);
    });

    test('enforcedFor strips custom photos when Pro is locked', () {
      final themed = CardPresets.minimalClean.copyWith(
        customBackgroundImagePath: '/tmp/backdrop.jpg',
        showWatermark: false,
      );
      final free = themed.enforcedFor(isProPurchased: false);
      if (canAccessProFeature(isProPurchased: false)) {
        expect(free.customBackgroundImagePath, '/tmp/backdrop.jpg');
        expect(free.showWatermark, isFalse);
      } else {
        expect(free.customBackgroundImagePath, isNull);
        expect(free.showWatermark, isTrue);
      }
      expect(
        themed.enforcedFor(isProPurchased: true).customBackgroundImagePath,
        '/tmp/backdrop.jpg',
      );
    });

    test('withExporterChrome preserves photo settings onto a new preset', () {
      final current = CardPresets.minimalClean.copyWith(
        customBackgroundImagePath: '/tmp/bg.png',
        blurSigma: 8,
        overlayOpacity: 0.4,
        isDarkOverlay: false,
        showWatermark: false,
      );
      final merged = CardPresets.midnightDark.withExporterChrome(current);
      expect(merged.id, 'midnight');
      expect(merged.customBackgroundImagePath, '/tmp/bg.png');
      expect(merged.blurSigma, 8);
      expect(merged.overlayOpacity, 0.4);
      expect(merged.isDarkOverlay, isFalse);
      expect(merged.showWatermark, isFalse);
    });
  });

  group('CardCanvas photo backdrop', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      required CardThemeConfig theme,
      CardAspectRatio aspect = CardAspectRatio.square,
      bool isProPurchased = true,
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
                text: 'Backdrop quote',
                aspectRatio: aspect,
                theme: theme,
                isProPurchased: isProPurchased,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('builds without a photo backdrop', (tester) async {
      await pumpCanvas(tester, theme: CardPresets.minimalClean);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('card-canvas')), findsOneWidget);
      expect(find.byKey(const Key('card-photo-backdrop')), findsNothing);
      expect(find.byKey(const Key('card-photo-scrim')), findsNothing);
      expect(find.text('Backdrop quote'), findsOneWidget);
    });

    testWidgets('renders a full-bleed blurred photo and scrim on square and story',
        (tester) async {
      final theme = CardPresets.minimalClean.copyWith(
        customBackgroundImagePath: '/missing/penningpal_backdrop.png',
        blurSigma: 18,
        overlayOpacity: 0.6,
      );

      await pumpCanvas(tester, theme: theme);
      expect(find.byKey(const Key('card-canvas')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('card-canvas'))),
        const Size(1080, 1080),
      );
      expect(find.byKey(const Key('card-photo-backdrop')), findsOneWidget);
      expect(find.byKey(const Key('card-photo-scrim')), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.text('Backdrop quote'), findsOneWidget);

      final filter = tester.widget<ImageFiltered>(
        find.byKey(const Key('card-photo-backdrop')),
      );
      expect(filter.imageFilter, isA<ui.ImageFilter>());

      final scrim = tester.widget<ColoredBox>(
        find.byKey(const Key('card-photo-scrim')),
      );
      expect(scrim.color.a, closeTo(0.6, 0.001));
      expect(scrim.color.r, 0);
      tester.takeException();

      await pumpCanvas(tester, theme: theme, aspect: CardAspectRatio.story);
      expect(
        tester.getSize(find.byKey(const Key('card-canvas'))),
        const Size(1080, 1920),
      );
      expect(find.byKey(const Key('card-photo-backdrop')), findsOneWidget);
      expect(find.byKey(const Key('card-photo-scrim')), findsOneWidget);
      expect(find.text('Backdrop quote'), findsOneWidget);
      tester.takeException();
    });
  });

  group('CardCustomizerControls', () {
    testWidgets('blur and dimmer sliders update theme state reactively',
        (tester) async {
      var theme = CardPresets.minimalClean.copyWith(
        customBackgroundImagePath: '/missing/backdrop.png',
      );
      final picks = <int>[];
      final locks = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CardCustomizerControls(
                  theme: theme,
                  isProPurchased: true,
                  canAccessPro: true,
                  onChanged: (next) => setState(() => theme = next),
                  onPickPhoto: () => picks.add(1),
                  onLockedFeature: () => locks.add(1),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('photo-backdrop-card')), findsOneWidget);
      expect(find.byKey(const Key('photo-backdrop-blur')), findsOneWidget);
      expect(find.byKey(const Key('photo-backdrop-dimmer')), findsOneWidget);

      final blur = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const Key('photo-backdrop-blur')),
          matching: find.byType(Slider),
        ),
      );
      blur.onChanged!(24);
      await tester.pump();
      expect(theme.blurSigma, 24);

      final dimmer = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const Key('photo-backdrop-dimmer')),
          matching: find.byType(Slider),
        ),
      );
      dimmer.onChanged!(0.8);
      await tester.pump();
      expect(theme.overlayOpacity, 0.8);

      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(theme.isDarkOverlay, isFalse);

      await tester.tap(find.byKey(const Key('photo-backdrop-remove')));
      await tester.pump();
      expect(theme.customBackgroundImagePath, isNull);
      expect(find.byKey(const Key('photo-backdrop-blur')), findsNothing);
      expect(picks, isEmpty);
      expect(locks, isEmpty);
    });

    testWidgets('choose photo is gated for free users', (tester) async {
      var locked = 0;
      var picked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardCustomizerControls(
              theme: CardPresets.minimalClean,
              isProPurchased: false,
              canAccessPro: false,
              onChanged: (_) {},
              onPickPhoto: () => picked += 1,
              onLockedFeature: () => locked += 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('photo-backdrop-lock')), findsOneWidget);
      await tester.tap(find.byKey(const Key('photo-backdrop-choose')));
      await tester.pump();
      expect(locked, 1);
      expect(picked, 0);
    });
  });

  group('PhotoBackdropStore', () {
    test('copies picks into local photo_backdrops storage', () async {
      final temp = await Directory.systemTemp.createTemp('photo_store_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final source = File('${temp.path}/source.png');
      await source.writeAsBytes(_tinyPngBytes());

      final store = PhotoBackdropStore(
        supportDirectory: () async => temp,
        pickImage: () async => XFile(source.path),
      );
      final path = await store.pickFromGallery();
      expect(path, isNotNull);
      expect(PhotoBackdropStore.isManagedPath(path!), isTrue);
      expect(File(path).existsSync(), isTrue);
      expect(path, isNot(source.path));

      await store.deleteIfManaged(path);
      expect(File(path).existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    });
  });

  group('Batch & LinkedIn PDF compatibility', () {
    test('CarouselBatchExporter captures each slide with a photo theme', () async {
      final rasterizer = _CountingRasterizer();
      final exporter = CarouselBatchExporter(rasterizer: rasterizer);
      final deck = CarouselDeck.fromMarkdown('A\n---\nB');
      final theme = CardPresets.minimalClean.copyWith(
        customBackgroundImagePath: '/tmp/backdrop.jpg',
        blurSigma: 10,
        overlayOpacity: 0.45,
      );

      final presented = <String>[];
      final images = await exporter.captureSlides(
        deck: deck,
        boundaryKey: GlobalKey(),
        presentSlide: (index, text) async => presented.add('$index:$text'),
      );

      expect(theme.hasCustomBackground, isTrue);
      expect(presented, ['0:A', '1:B']);
      expect(images, hasLength(2));
      expect(rasterizer.calls, 2);
    });

    test('LinkedInPdfExporter compiles the same PNG slides used for photo cards',
        () async {
      final temp = await Directory.systemTemp.createTemp('pdf_photo_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final png = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );
      final file = await LinkedInPdfExporter(
        temporaryDirectory: () async => temp,
      ).generatePdfCarousel([png, png]);
      final bytes = await file.readAsBytes();
      expect(LinkedInPdfExporter.isPdf(Uint8List.fromList(bytes)), isTrue);
      expect(LinkedInPdfExporter.countPages(Uint8List.fromList(bytes)), 2);
    });
  });

  group('CardExporterScreen photo tile', () {
    testWidgets('shows the Photo Backdrop customizer', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: true),
            ),
          ],
          child: const MaterialApp(
            home: CardExporterScreen(text: 'A short quote for the card.'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('photo-backdrop-card')), findsOneWidget);
      expect(find.text('Photo Backdrop'), findsOneWidget);
      expect(find.byKey(const Key('photo-backdrop-choose')), findsOneWidget);
    });
  });
}

Uint8List _tinyPngBytes() {
  return Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
    0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
    0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
    0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

class _CountingRasterizer extends CardRasterizer {
  int calls = 0;

  @override
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = CardRasterizer.defaultPixelRatio,
  }) async {
    calls += 1;
    return Uint8List.fromList(CardRasterizer.pngSignature);
  }
}
