import 'dart:typed_data';

import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/presentation/card_inspect_modal.dart';
import 'package:clean_canvas/features/exporter/render/card_export_service.dart';
import 'package:clean_canvas/features/exporter/render/card_rasterizer.dart';
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

  final png = Uint8List.fromList([
    ...CardRasterizer.pngSignature,
    0,
    1,
    2,
    3,
  ]);

  group('CardExportService.copyImageToClipboard', () {
    test('writes PNG bytes and returns true', () async {
      Uint8List? captured;
      var calls = 0;
      final service = CardExportService(
        writePngToClipboard: (bytes) async {
          calls += 1;
          captured = bytes;
          return true;
        },
      );

      expect(await service.copyImageToClipboard(png), isTrue);
      expect(calls, 1);
      expect(captured, png);
    });

    test('returns false for empty or non-PNG buffers', () async {
      var calls = 0;
      final service = CardExportService(
        writePngToClipboard: (bytes) async {
          calls += 1;
          return true;
        },
      );

      expect(await service.copyImageToClipboard(Uint8List(0)), isFalse);
      expect(
        await service.copyImageToClipboard(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
        isFalse,
      );
      expect(calls, 0);
    });

    test('returns false when the system clipboard is unavailable', () async {
      final service = const CardExportService();
      expect(await service.copyImageToClipboard(png), isFalse);
    });
  });

  group('CardExporterScreen copy + inspect', () {
    Future<void> pumpExporter(
      WidgetTester tester, {
      String text = 'Share me',
      required CardRasterizer rasterizer,
      required CardExportService exportService,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
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
          child: MaterialApp(
            home: CardExporterScreen(
              text: text,
              rasterizer: rasterizer,
              exportService: exportService,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Copy Card rasterizes the visible slide and copies PNG bytes',
        (tester) async {
      final rasterizer = _FakeRasterizer();
      final export = RecordingClipboardExportService();
      await pumpExporter(
        tester,
        rasterizer: rasterizer,
        exportService: export,
      );

      expect(find.text('Copy Card'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copy-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rasterizer.calls, 1);
      expect(export.copies, hasLength(1));
      expect(export.copies.single, rasterizer.png);
      expect(
        find.text('Card copied to clipboard! Ready to paste.'),
        findsOneWidget,
      );
    });

    testWidgets('Copy Card copies the currently visible carousel slide',
        (tester) async {
      final rasterizer = _FakeRasterizer();
      final export = RecordingClipboardExportService();
      await pumpExporter(
        tester,
        text: 'First slide\n---\nSecond slide',
        rasterizer: rasterizer,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('carousel-next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('copy-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rasterizer.calls, 1);
      expect(export.copies, hasLength(1));
      expect(export.shareAllCalls, isEmpty);
    });

    testWidgets('tapping the card preview opens the pinch-to-zoom inspect modal',
        (tester) async {
      await pumpExporter(
        tester,
        rasterizer: _FakeRasterizer(),
        exportService: RecordingClipboardExportService(),
      );

      expect(find.byType(CardInspectModal), findsNothing);

      await tester.tap(find.byKey(const Key('card-preview-tap')));
      await tester.pumpAndSettle();

      expect(find.byType(CardInspectModal), findsOneWidget);
      expect(find.byKey(const Key('card-inspect-modal')), findsOneWidget);
      expect(find.byKey(const Key('card-inspect-viewer')), findsOneWidget);

      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const Key('card-inspect-viewer')),
      );
      expect(viewer.minScale, 0.8);
      expect(viewer.maxScale, 4.0);

      await tester.tap(find.byKey(const Key('card-inspect-close')));
      await tester.pumpAndSettle();
      expect(find.byType(CardInspectModal), findsNothing);
    });

    testWidgets('copy failure shows an error toast', (tester) async {
      final export = RecordingClipboardExportService(copyResult: false);
      await pumpExporter(
        tester,
        rasterizer: _FakeRasterizer(),
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('copy-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Could not copy card'), findsOneWidget);
    });
  });
}

class _FakeRasterizer extends CardRasterizer {
  int calls = 0;
  final Uint8List png = Uint8List.fromList(CardRasterizer.pngSignature);

  @override
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = CardRasterizer.defaultPixelRatio,
  }) async {
    calls += 1;
    return png;
  }
}

class RecordingClipboardExportService extends CardExportService {
  RecordingClipboardExportService({this.copyResult = true});

  final bool copyResult;
  final List<Uint8List> copies = <Uint8List>[];
  final List<List<Uint8List>> shareAllCalls = <List<Uint8List>>[];

  @override
  Future<bool> copyImageToClipboard(Uint8List pngBytes) async {
    copies.add(pngBytes);
    return copyResult;
  }

  @override
  Future<void> shareAllSlides(
    List<Uint8List> slidesImages, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    shareAllCalls.add(slidesImages);
  }
}
