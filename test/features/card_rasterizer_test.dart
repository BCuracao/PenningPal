import 'dart:typed_data';

import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/render/card_export_service.dart';
import 'package:clean_canvas/features/exporter/render/card_rasterizer.dart';
import 'package:clean_canvas/features/exporter/templates/card_theme_config.dart';
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

  group('CardThemeConfig presets', () {
    test('Minimal Clean uses light paper, charcoal type, and a watermark', () {
      const theme = CardPresets.minimalClean;
      expect(theme.id, 'minimal');
      expect(theme.backgroundColor, const Color(0xFFF8F9FA));
      expect(theme.textColor, const Color(0xFF1F2937));
      expect(theme.accentColor, const Color(0xFF94A3B8));
      expect(theme.fontFamily, CardThemeConfig.fontInter);
      expect(theme.showWatermark, isTrue);
      expect(theme.isPremium, isFalse);
      expect(theme.backgroundGradient, isNull);
      expect(theme.variant, CardTemplateVariant.plain);
    });

    test('Midnight Dark uses slate, off-white type, and a gradient', () {
      const theme = CardPresets.midnightDark;
      expect(theme.id, 'midnight');
      expect(theme.backgroundColor, const Color(0xFF0F172A));
      expect(theme.textColor, const Color(0xFFF8FAFC));
      expect(theme.fontFamily, CardThemeConfig.fontInter);
      expect(theme.showWatermark, isTrue);
      expect(theme.isPremium, isTrue);
      expect(theme.backgroundGradient, isA<LinearGradient>());
    });

    test('Dev Terminal is monospace with terminal chrome', () {
      const theme = CardPresets.devTerminal;
      expect(theme.id, 'terminal');
      expect(theme.backgroundColor, const Color(0xFF1E1E1E));
      expect(theme.textColor, const Color(0xFFD4D4D4));
      expect(theme.fontFamily, CardThemeConfig.fontJetBrainsMono);
      expect(theme.isMonospace, isTrue);
      expect(theme.variant, CardTemplateVariant.terminal);
      expect(theme.isPremium, isTrue);
      expect(theme.showWatermark, isTrue);
    });

    test('copyWith can hide the watermark without mutating the preset', () {
      const original = CardPresets.minimalClean;
      final stripped = original.copyWith(showWatermark: false);
      expect(original.showWatermark, isTrue);
      expect(stripped.showWatermark, isFalse);
      expect(stripped.backgroundColor, original.backgroundColor);
    });

    test('enforcedFor forces the watermark when the user is not Pro', () {
      final stripped = CardPresets.minimalClean.copyWith(showWatermark: false);
      expect(stripped.enforcedFor(isProPurchased: false).showWatermark, isTrue);
      expect(stripped.enforcedFor(isProPurchased: true).showWatermark, isFalse);
    });

    test('byId falls back to Minimal Clean', () {
      expect(CardPresets.byId('midnight'), CardPresets.midnightDark);
      expect(CardPresets.byId('missing'), CardPresets.minimalClean);
    });
  });

  group('CardAspectRatio & layout metrics', () {
    test('social dimensions are exactly 1080×1080 and 1080×1920', () {
      expect(CardAspectRatio.square.width, 1080);
      expect(CardAspectRatio.square.height, 1080);
      expect(CardAspectRatio.story.width, 1080);
      expect(CardAspectRatio.story.height, 1920);
    });

    test('soft character limits flag overflow', () {
      expect(CardAspectRatio.square.exceedsSoftLimit('short'), isFalse);
      expect(
        CardAspectRatio.square.exceedsSoftLimit('x' * 281),
        isTrue,
      );
      expect(
        CardAspectRatio.story.exceedsSoftLimit('x' * 280),
        isFalse,
      );
      expect(
        CardAspectRatio.story.exceedsSoftLimit('x' * 641),
        isTrue,
      );
    });

    test('font size shrinks as the draft grows', () {
      expect(
        CardLayout.fontSizeFor('Hi', CardAspectRatio.square),
        greaterThan(
          CardLayout.fontSizeFor('x' * 400, CardAspectRatio.square),
        ),
      );
      expect(
        CardLayout.fontSizeFor('Hi', CardAspectRatio.story),
        greaterThan(
          CardLayout.fontSizeFor('x' * 600, CardAspectRatio.story),
        ),
      );
    });
  });

  group('CardCanvas', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      required String text,
      CardAspectRatio aspect = CardAspectRatio.square,
      CardThemeConfig theme = CardPresets.minimalClean,
      String? author,
      GlobalKey? canvasKey,
      bool isProPurchased = false,
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
                canvasKey: canvasKey ?? GlobalKey(),
                text: text,
                aspectRatio: aspect,
                theme: theme,
                author: author,
                isProPurchased: isProPurchased,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('square canvas is 1080×1080 and shows the draft', (
      tester,
    ) async {
      await pumpCanvas(tester, text: 'Hello canvas');

      expect(tester.takeException(), isNull);
      final box = tester.getSize(find.byKey(const Key('card-canvas')));
      expect(box, const Size(1080, 1080));
      expect(find.byKey(const Key('card-body-text')), findsOneWidget);
      expect(find.text('Hello canvas'), findsOneWidget);
      expect(find.text(CardLayout.watermarkLabel), findsOneWidget);
    });

    testWidgets('story canvas is 1080×1920', (tester) async {
      await pumpCanvas(
        tester,
        text: 'Story card',
        aspect: CardAspectRatio.story,
      );

      expect(tester.takeException(), isNull);
      final box = tester.getSize(find.byKey(const Key('card-canvas')));
      expect(box, const Size(1080, 1920));
    });

    testWidgets('long drafts do not throw layout overflow', (tester) async {
      final long = List.generate(80, (i) => 'Line $i of a very long draft.')
          .join('\n');

      await pumpCanvas(tester, text: long);
      expect(tester.takeException(), isNull);

      await pumpCanvas(
        tester,
        text: long,
        aspect: CardAspectRatio.story,
        theme: CardPresets.midnightDark,
      );
      expect(tester.takeException(), isNull);

      await pumpCanvas(
        tester,
        text: long,
        aspect: CardAspectRatio.story,
        theme: CardPresets.devTerminal,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
    });

    testWidgets('watermark respects showWatermark for Pro users', (
      tester,
    ) async {
      await pumpCanvas(
        tester,
        text: 'Quote',
        theme: CardPresets.minimalClean.copyWith(showWatermark: false),
        isProPurchased: true,
      );
      expect(find.byKey(const Key('card-watermark')), findsNothing);
    });

    testWidgets('author fills the branding slot', (tester) async {
      await pumpCanvas(tester, text: 'Quote', author: '@clean_canvas');
      expect(find.text('@clean_canvas'), findsOneWidget);
    });
  });

  group('CardRasterizer', () {
    test('unmounted keys return null', () async {
      final bytes = await const CardRasterizer().capturePng(GlobalKey());
      expect(bytes, isNull);
    });

    testWidgets('captures a PNG from the card RepaintBoundary', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final canvasKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FittedBox(
              child: CardCanvas(
                canvasKey: canvasKey,
                text: 'Raster me',
                aspectRatio: CardAspectRatio.square,
                theme: CardPresets.minimalClean,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // `toImage` talks to the raster thread; the test zone must yield to it.
      final bytes = await tester.runAsync(
        () => const CardRasterizer().capturePng(canvasKey, pixelRatio: 1.0),
      );
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(32));
      expect(bytes.sublist(0, 8), CardRasterizer.pngSignature);
    });
  });

  group('CardExporterScreen', () {
    Widget wrapExporter(Widget home) {
      return ProviderScope(
        overrides: [
          paywallServiceProvider.overrideWithValue(
            FakePaywallService(hasProAccess: true),
          ),
        ],
        child: home,
      );
    }

    testWidgets('preview, aspect switch, templates, and overflow meter', (
      tester,
    ) async {
      const draft = 'A short quote for the card.';
      await tester.pumpWidget(
        wrapExporter(
          const MaterialApp(
            home: CardExporterScreen(text: draft),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CardCanvas), findsOneWidget);
      expect(find.byKey(const Key('card-preview')), findsOneWidget);
      expect(find.text(draft), findsOneWidget);
      expect(find.text('Teilen'), findsOneWidget);
      expect(find.text('In Fotos sichern'), findsOneWidget);
      expect(find.byKey(const Key('card-overflow-warning')), findsNothing);

      await tester.tap(find.byKey(const Key('card-aspect-story')));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('card-canvas'))),
        const Size(1080, 1920),
      );

      await tester.ensureVisible(find.byKey(const Key('card-template-terminal')));
      await tester.tap(find.byKey(const Key('card-template-terminal')));
      await tester.pump();
      expect(find.byKey(const Key('terminal-traffic-lights')), findsOneWidget);
    });

    testWidgets('shows a length warning when the draft exceeds capacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapExporter(
          MaterialApp(
            home: CardExporterScreen(text: 'x' * 400),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('card-overflow-warning')), findsOneWidget);
      expect(find.byKey(const Key('card-char-meter')), findsOneWidget);
    });

    testWidgets('Teilen rasterizes via the provided rasterizer', (
      tester,
    ) async {
      final rasterizer = _FakeRasterizer();
      await tester.pumpWidget(
        wrapExporter(
          MaterialApp(
            home: CardExporterScreen(
              text: 'Export me',
              rasterizer: rasterizer,
              exportService: _NoopExportService(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('share-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rasterizer.calls, 1);
    });
  });
}

class _FakeRasterizer extends CardRasterizer {
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

class _NoopExportService extends CardExportService {
  @override
  Future<void> shareCardImage(
    Uint8List byteData, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {}

  @override
  Future<bool> saveToGallery(Uint8List byteData, {String? albumName}) async {
    return true;
  }
}
