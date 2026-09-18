import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/render/card_export_service.dart';
import 'package:clean_canvas/features/exporter/render/card_rasterizer.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

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

  group('filename generation', () {
    test('generateFilename is timestamped and ends in .png', () {
      final name = CardExportService.generateFilename(
        now: DateTime(2026, 9, 18, 15, 4, 7),
      );
      expect(name, 'clean_canvas_20260918_150407.png');
    });

    test('sanitizeFilename strips paths and illegal characters', () {
      expect(
        CardExportService.sanitizeFilename(r'..\..\My Card!.PNG'),
        'My_Card.png',
      );
      expect(CardExportService.sanitizeFilename('quote'), 'quote.png');
      expect(
        CardExportService.sanitizeFilename('   '),
        '${CardExportService.defaultFileStem}.png',
      );
      expect(
        CardExportService.sanitizeFilename('.'),
        '${CardExportService.defaultFileStem}.png',
      );
    });
  });

  group('byte-array validation', () {
    test('rejects empty buffers', () {
      expect(
        () => CardExportService.ensureValidPngBytes(Uint8List(0)),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('empty'),
          ),
        ),
      );
      expect(CardExportService.isValidPngBytes(Uint8List(0)), isFalse);
    });

    test('rejects truncated and non-PNG buffers', () {
      expect(
        CardExportService.isValidPngBytes(Uint8List.fromList([137, 80, 78])),
        isFalse,
      );
      expect(
        CardExportService.isValidPngBytes(
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        ),
        isFalse,
      );
      expect(
        () => CardExportService.ensureValidPngBytes(
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        ),
        throwsArgumentError,
      );
      expect(CardExportService.isValidPngBytes(png), isTrue);
    });

    test('saveImageTemporarily refuses empty and invalid bytes', () async {
      final service = CardExportService(
        temporaryDirectory: () async => Directory.systemTemp,
      );
      await expectLater(
        service.saveImageTemporarily(Uint8List(0), 'card.png'),
        throwsArgumentError,
      );
      await expectLater(
        service.saveImageTemporarily(
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]),
          'card.png',
        ),
        throwsArgumentError,
      );
    });

    test('saveToGallery returns false for invalid bytes', () async {
      var putCalls = 0;
      final service = CardExportService(
        hasGalleryAccess: ({toAlbum = false}) async => true,
        putImageBytes: (bytes, {album, name = 'image'}) async {
          putCalls += 1;
        },
      );

      expect(await service.saveToGallery(Uint8List(0)), isFalse);
      expect(
        await service.saveToGallery(Uint8List.fromList([9, 8, 7, 6, 5, 4, 3, 2])),
        isFalse,
      );
      expect(putCalls, 0);
    });
  });

  group('CardExportService IO', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('clean_canvas_export_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveImageTemporarily writes sanitized filename into the cache',
        () async {
      final service = CardExportService(
        temporaryDirectory: () async => tempDir,
      );

      final file = await service.saveImageTemporarily(png, r'folder/My Card.png');
      expect(file.path, endsWith('My_Card.png'));
      expect(await file.readAsBytes(), png);
    });

    test('saveToGallery writes after access is granted', () async {
      Uint8List? saved;
      String? capturedAlbum;
      String? capturedName;
      final service = CardExportService(
        hasGalleryAccess: ({toAlbum = false}) async => false,
        requestGalleryAccess: ({toAlbum = false}) async => true,
        putImageBytes: (bytes, {album, name = 'image'}) async {
          saved = bytes;
          capturedAlbum = album;
          capturedName = name;
        },
      );

      expect(await service.saveToGallery(png, albumName: 'Quotes'), isTrue);
      expect(saved, png);
      expect(capturedAlbum, 'Quotes');
      expect(capturedName, isNotEmpty);
      expect(capturedName, isNot(contains('.')));
    });

    test('saveToGallery returns false when the user denies Photos access',
        () async {
      var putCalls = 0;
      final service = CardExportService(
        hasGalleryAccess: ({toAlbum = false}) async => false,
        requestGalleryAccess: ({toAlbum = false}) async => false,
        putImageBytes: (bytes, {album, name = 'image'}) async {
          putCalls += 1;
        },
      );

      expect(await service.saveToGallery(png), isFalse);
      expect(putCalls, 0);
    });

    test('saveToGallery swallows plugin errors', () async {
      final service = CardExportService(
        hasGalleryAccess: ({toAlbum = false}) async => true,
        putImageBytes: (bytes, {album, name = 'image'}) async {
          throw Exception('gallery unavailable');
        },
      );

      expect(await service.saveToGallery(png), isFalse);
    });

    test('shareCardImage stores a temp PNG then opens the share sheet',
        () async {
      final shared = <XFile>[];
      String? sharedText;
      final service = CardExportService(
        temporaryDirectory: () async => tempDir,
        shareFiles: (files, {text = '', sharePositionOrigin}) async {
          shared.addAll(files);
          sharedText = text;
        },
      );

      await service.shareCardImage(png, text: 'Made with Clean Canvas');
      expect(shared, hasLength(1));
      expect(shared.single.mimeType, 'image/png');
      expect(sharedText, 'Made with Clean Canvas');
      expect(File(shared.single.path).existsSync(), isTrue);
      expect(await File(shared.single.path).readAsBytes(), png);
    });
  });

  group('CardExporterScreen actions', () {
    Future<void> pumpExporter(
      WidgetTester tester, {
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
              text: 'Share me',
              rasterizer: rasterizer,
              exportService: exportService,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Teilen captures PNG bytes and shares them', (tester) async {
      final rasterizer = _FakeRasterizer();
      final export = RecordingExportService();
      await pumpExporter(
        tester,
        rasterizer: rasterizer,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('share-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rasterizer.calls, 1);
      expect(export.shares, hasLength(1));
      expect(export.shares.single, rasterizer.png);
      expect(export.saves, isEmpty);
    });

    testWidgets('In Fotos sichern saves and shows a confirmation toast',
        (tester) async {
      final rasterizer = _FakeRasterizer();
      final export = RecordingExportService();
      await pumpExporter(
        tester,
        rasterizer: rasterizer,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('save-card-gallery')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rasterizer.calls, 1);
      expect(export.saves, hasLength(1));
      expect(find.text('In Fotos gespeichert'), findsOneWidget);
    });

    testWidgets('denied gallery access shows a failure toast', (tester) async {
      final export = RecordingExportService(saveResult: false);
      await pumpExporter(
        tester,
        rasterizer: _FakeRasterizer(),
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('save-card-gallery')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Speichern nicht möglich'), findsOneWidget);
    });

    testWidgets('export buttons show a spinner and ignore extra taps',
        (tester) async {
      final rasterizer = _GatedRasterizer();
      final export = RecordingExportService();
      await pumpExporter(
        tester,
        rasterizer: rasterizer,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('share-card-png')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('share-card-png')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-card-gallery')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('save-card-gallery')));
      rasterizer.release.complete(rasterizer.png);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(export.shares, hasLength(1));
      expect(export.saves, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
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

class _GatedRasterizer extends CardRasterizer {
  final Completer<Uint8List?> release = Completer<Uint8List?>();
  final Uint8List png = Uint8List.fromList(CardRasterizer.pngSignature);

  @override
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = CardRasterizer.defaultPixelRatio,
  }) {
    return release.future;
  }
}

class RecordingExportService extends CardExportService {
  RecordingExportService({this.saveResult = true});

  final bool saveResult;
  final List<Uint8List> shares = <Uint8List>[];
  final List<Uint8List> saves = <Uint8List>[];

  @override
  Future<void> shareCardImage(
    Uint8List byteData, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    shares.add(byteData);
  }

  @override
  Future<bool> saveToGallery(Uint8List byteData, {String? albumName}) async {
    saves.add(byteData);
    return saveResult;
  }
}
