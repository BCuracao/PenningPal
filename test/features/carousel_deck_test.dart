import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clean_canvas/features/exporter/models/carousel_deck.dart';
import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/render/card_export_service.dart';
import 'package:clean_canvas/features/exporter/render/card_rasterizer.dart';
import 'package:clean_canvas/features/exporter/render/carousel_batch_exporter.dart';
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

  group('CarouselDeck.fromMarkdown', () {
    test('treats a draft with no divider as a single slide', () {
      const raw = 'Just a quote with **bold** and a dash - in prose.';
      final deck = CarouselDeck.fromMarkdown(raw);

      expect(deck.slides, [raw]);
      expect(deck.totalSlides, 1);
      expect(deck.isCarousel, isFalse);
    });

    test('splits on --- with surrounding newlines', () {
      final deck = CarouselDeck.fromMarkdown('First\n---\nSecond');
      expect(deck.slides, ['First', 'Second']);
      expect(deck.totalSlides, 2);
      expect(deck.isCarousel, isTrue);
    });

    test('splits on *** and ___ thematic breaks', () {
      expect(
        CarouselDeck.fromMarkdown('Alpha\n***\nBeta').slides,
        ['Alpha', 'Beta'],
      );
      expect(
        CarouselDeck.fromMarkdown('Alpha\n___\nBeta').slides,
        ['Alpha', 'Beta'],
      );
    });

    test('allows extra dashes/stars/underscores beyond three', () {
      expect(
        CarouselDeck.fromMarkdown('One\n----\nTwo').slides,
        ['One', 'Two'],
      );
      expect(
        CarouselDeck.fromMarkdown('One\n*****\nTwo').slides,
        ['One', 'Two'],
      );
      expect(
        CarouselDeck.fromMarkdown('One\n____\nTwo').slides,
        ['One', 'Two'],
      );
    });

    test('tolerates varied whitespace around the divider', () {
      expect(
        CarouselDeck.fromMarkdown('One\n  ---  \nTwo').slides,
        ['One', 'Two'],
      );
      expect(
        CarouselDeck.fromMarkdown('One\n\n\t---\t\n\nTwo').slides,
        ['One', 'Two'],
      );
      expect(
        CarouselDeck.fromMarkdown('One\n *** \nTwo').slides,
        ['One', 'Two'],
      );
    });

    test('normalizes CRLF before splitting', () {
      final deck = CarouselDeck.fromMarkdown('One\r\n---\r\nTwo');
      expect(deck.slides, ['One', 'Two']);
    });

    test('the 3-slide mixed-newline snippet yields three slides', () {
      const raw =
          '# Hook\r\nOpening.\r\n\r\n---\r\n\r\n## Insight\nBody.\n\n***\n\n> Close';
      final deck = CarouselDeck.fromMarkdown(raw);
      expect(deck.slides, hasLength(3));
      expect(deck.slides[0], contains('Hook'));
      expect(deck.slides[1], contains('Insight'));
      expect(deck.slides[2], contains('Close'));
    });

    test('trims slide bodies and discards empty segments', () {
      final deck = CarouselDeck.fromMarkdown(
        '\n  First  \n\n---\n\n\n---\n  Second  \n',
      );
      expect(deck.slides, ['First', 'Second']);
    });

    test('leading or trailing dividers do not create empty slides', () {
      expect(
        CarouselDeck.fromMarkdown('---\nOnly slide\n---').slides,
        ['Only slide'],
      );
      expect(
        CarouselDeck.fromMarkdown('---\nOnly slide\n---').isCarousel,
        isFalse,
      );
    });

    test('inline dashes and emphasis markers are not dividers', () {
      const raw = 'Wait --- what about ***this*** and foo_bar?';
      final deck = CarouselDeck.fromMarkdown(raw);
      expect(deck.slides, [raw]);
      expect(deck.isCarousel, isFalse);
    });

    test('falls back to a single empty slide when the draft is blank', () {
      final deck = CarouselDeck.fromMarkdown('   \n  ');
      expect(deck.slides, ['']);
      expect(deck.totalSlides, 1);
      expect(deck.isCarousel, isFalse);
    });

    test('falls back to one slide when every split segment is empty', () {
      final deck = CarouselDeck.fromMarkdown('---\n\n---');
      expect(deck.totalSlides, 1);
      expect(deck.isCarousel, isFalse);
    });

    test('slideAt clamps to the available range', () {
      final deck = CarouselDeck.fromMarkdown('A\n---\nB\n---\nC');
      expect(deck.slideAt(-2), 'A');
      expect(deck.slideAt(1), 'B');
      expect(deck.slideAt(99), 'C');
    });
  });

  group('pagination indicator formatting', () {
    test('formats zero-based indices as 1-based fractions', () {
      expect(CarouselDeck.formatPagination(0, 5), '1 / 5');
      expect(CarouselDeck.formatPagination(4, 5), '5 / 5');
      expect(CarouselDeck.formatPagination(-3, 5), '1 / 5');
      expect(CarouselDeck.formatPagination(99, 5), '5 / 5');
    });

    test('formats the Slide X of Y banner', () {
      expect(CarouselDeck.formatSlideOf(0, 3), 'Slide 1 of 3');
      expect(CarouselDeck.formatSlideOf(2, 3), 'Slide 3 of 3');
    });

    test('instance helpers use the deck length', () {
      final deck = CarouselDeck.fromMarkdown('A\n---\nB\n---\nC');
      expect(deck.paginationLabel(1), '2 / 3');
      expect(deck.slideOfLabel(1), 'Slide 2 of 3');
    });

    test('guards a zero or negative total', () {
      expect(CarouselDeck.formatPagination(0, 0), '1 / 1');
      expect(CarouselDeck.formatSlideOf(0, -1), 'Slide 1 of 1');
    });
  });

  group('CardCanvas pagination badge', () {
    Future<void> pumpCanvas(
      WidgetTester tester, {
      int? currentSlideIndex,
      int? totalSlides,
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
                theme: CardPresets.minimalClean,
                currentSlideIndex: currentSlideIndex,
                totalSlides: totalSlides,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hides the badge when totalSlides is null or 1', (tester) async {
      await pumpCanvas(tester);
      expect(find.byKey(const Key('card-pagination-badge')), findsNothing);

      await pumpCanvas(tester, currentSlideIndex: 0, totalSlides: 1);
      expect(find.byKey(const Key('card-pagination-badge')), findsNothing);
    });

    testWidgets('shows a 1-based pill that clears the watermark and header',
        (tester) async {
      await pumpCanvas(tester, currentSlideIndex: 0, totalSlides: 5);

      expect(find.byKey(const Key('card-pagination-badge')), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text(CardLayout.watermarkLabel), findsOneWidget);
      expect(find.text('PenningPal'), findsOneWidget);

      final badge =
          tester.getRect(find.byKey(const Key('card-pagination-badge')));
      final watermark = tester.getRect(find.byKey(const Key('card-watermark')));
      final brand = tester.getRect(find.byKey(const Key('card-brand-slot')));
      expect(badge.overlaps(watermark), isFalse);
      expect(badge.overlaps(brand), isFalse);
    });
  });

  group('CardExporterScreen carousel paging', () {
    const draft = 'First slide\n\n---\n\nSecond slide\n\n---\n\nThird slide';

    Future<void> pumpExporter(
      WidgetTester tester, {
      String text = draft,
      CardRasterizer? rasterizer,
      CardExportService? exportService,
      CarouselBatchExporter? batchExporter,
      bool isPro = true,
    }) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: isPro),
            ),
          ],
          child: MaterialApp(
            home: CardExporterScreen(
              text: text,
              rasterizer: rasterizer ?? const CardRasterizer(),
              exportService: exportService ?? _NoopExportService(),
              batchExporter: batchExporter ?? const CarouselBatchExporter(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('pages slides, shows Slide X of Y, and uses batch labels',
        (tester) async {
      await pumpExporter(tester);

      expect(find.byKey(const Key('carousel-page-view')), findsOneWidget);
      expect(find.byKey(const Key('carousel-slide-banner')), findsOneWidget);
      expect(find.text('Slide 1 of 3'), findsOneWidget);
      expect(find.text('Share Carousel (3 Slides)'), findsOneWidget);
      expect(find.text('Save All (3 Slides)'), findsOneWidget);
      expect(find.text('First slide'), findsOneWidget);

      await tester.tap(find.byKey(const Key('carousel-next')));
      await tester.pumpAndSettle();

      expect(find.text('Slide 2 of 3'), findsOneWidget);
      expect(find.text('Second slide'), findsOneWidget);
    });

    testWidgets('single-slide drafts keep the static preview and image labels',
        (tester) async {
      await pumpExporter(tester, text: 'Just one quote');

      expect(find.byKey(const Key('carousel-page-view')), findsNothing);
      expect(find.text('Share Image'), findsOneWidget);
      expect(find.text('Save Image'), findsOneWidget);
      expect(find.text('Just one quote'), findsOneWidget);
    });

    testWidgets('Share Carousel rasterizes every slide then shares them all',
        (tester) async {
      final batch = _FakeBatchExporter();
      final export = RecordingCarouselExportService();
      await pumpExporter(
        tester,
        batchExporter: batch,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('share-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(batch.calls, 1);
      expect(batch.lastPro, isTrue);
      expect(export.shareAllCalls, hasLength(1));
      expect(export.shareAllCalls.single, hasLength(3));
    });

    testWidgets('Save All writes every slide and shows export progress',
        (tester) async {
      final batch = _GatedBatchExporter();
      final export = RecordingCarouselExportService();
      await pumpExporter(
        tester,
        batchExporter: batch,
        exportService: export,
      );

      await tester.tap(find.byKey(const Key('save-card-gallery')));
      await tester.pump();

      expect(find.byKey(const Key('carousel-export-progress')), findsOneWidget);
      expect(find.text('Exporting slide 1 of 3...'), findsOneWidget);

      batch.release.complete(batch.pngs);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(export.saveAllCalls, hasLength(1));
      expect(export.saveAllCalls.single, hasLength(3));
      expect(find.text('3 slides saved to Photos'), findsOneWidget);
    });

    testWidgets('unentitled carousel export still forces watermarks',
        (tester) async {
      final batch = _FakeBatchExporter();
      await pumpExporter(
        tester,
        isPro: false,
        batchExporter: batch,
        exportService: RecordingCarouselExportService(),
      );

      await tester.tap(find.byKey(const Key('share-card-png')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(batch.lastPro, isFalse);
      expect(find.byKey(const Key('card-watermark')), findsWidgets);
    });
  });

  group('CarouselBatchExporter', () {
    test('captureSlides presents and rasterizes each slide in order', () async {
      final rasterizer = _CountingRasterizer();
      final exporter = CarouselBatchExporter(rasterizer: rasterizer);
      final presented = <String>[];
      final progress = <int>[];
      final deck = CarouselDeck.fromMarkdown('A\n---\nB\n---\nC');

      final images = await exporter.captureSlides(
        deck: deck,
        boundaryKey: GlobalKey(),
        presentSlide: (index, text) async => presented.add('$index:$text'),
        onProgress: (current, total) => progress.add(current),
      );

      expect(presented, ['0:A', '1:B', '2:C']);
      expect(progress, [1, 2, 3]);
      expect(images, hasLength(3));
      expect(rasterizer.calls, 3);
    });

    test('captureSlides throws when a frame fails to rasterize', () async {
      final exporter = CarouselBatchExporter(
        rasterizer: _CountingRasterizer(succeed: false),
      );
      final deck = CarouselDeck.fromMarkdown('A\n---\nB');

      await expectLater(
        exporter.captureSlides(
          deck: deck,
          boundaryKey: GlobalKey(),
          presentSlide: (index, text) async {},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CardExportService batch IO', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('carousel_export_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('shareAllSlides writes unique temp PNGs and shares them together',
        () async {
      final shared = <List<String>>[];
      final service = CardExportService(
        temporaryDirectory: () async => tempDir,
        shareFiles: (files, {text = '', sharePositionOrigin}) async {
          shared.add(files.map((file) => file.path).toList());
        },
      );
      final png = Uint8List.fromList(CardRasterizer.pngSignature);

      await service.shareAllSlides([png, png, png]);

      expect(shared, hasLength(1));
      expect(shared.single, hasLength(3));
      expect(shared.single.toSet(), hasLength(3));
      for (final path in shared.single) {
        expect(path, contains('slide_'));
        expect(path, endsWith('.png'));
      }
    });

    test('saveAllToGallery saves each slide sequentially and returns the count',
        () async {
      final names = <String>[];
      final service = CardExportService(
        hasGalleryAccess: ({toAlbum = false}) async => true,
        putImageBytes: (bytes, {album, name = 'image'}) async {
          names.add(name);
        },
      );
      final png = Uint8List.fromList([...CardRasterizer.pngSignature, 1, 2]);

      final saved = await service.saveAllToGallery([png, png]);
      expect(saved, 2);
      expect(names, hasLength(2));
    });
  });
}

class _CountingRasterizer extends CardRasterizer {
  _CountingRasterizer({this.succeed = true});

  final bool succeed;
  int calls = 0;

  @override
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = CardRasterizer.defaultPixelRatio,
  }) async {
    calls += 1;
    if (!succeed) return null;
    return Uint8List.fromList(CardRasterizer.pngSignature);
  }
}

class _FakeBatchExporter extends CarouselBatchExporter {
  int calls = 0;
  bool? lastPro;

  @override
  Future<List<Uint8List>> renderDeck(
    CarouselDeck deck,
    CardThemeConfig config,
    CardAspectRatio ratio,
    bool isProPurchased, {
    required BuildContext context,
    String? author,
    void Function(int current, int total)? onProgress,
  }) async {
    calls += 1;
    lastPro = isProPurchased;
    onProgress?.call(1, deck.totalSlides);
    return List<Uint8List>.generate(
      deck.totalSlides,
      (_) => Uint8List.fromList(CardRasterizer.pngSignature),
    );
  }
}

class _GatedBatchExporter extends CarouselBatchExporter {
  final pngs = List<Uint8List>.generate(
    3,
    (_) => Uint8List.fromList(CardRasterizer.pngSignature),
  );
  final release = Completer<List<Uint8List>>();

  @override
  Future<List<Uint8List>> renderDeck(
    CarouselDeck deck,
    CardThemeConfig config,
    CardAspectRatio ratio,
    bool isProPurchased, {
    required BuildContext context,
    String? author,
    void Function(int current, int total)? onProgress,
  }) async {
    onProgress?.call(1, 3);
    return release.future;
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
  Future<bool> saveToGallery(
    Uint8List byteData, {
    String? albumName,
    String? filename,
  }) async {
    return true;
  }

  @override
  Future<void> shareAllSlides(
    List<Uint8List> slidesImages, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {}

  @override
  Future<int> saveAllToGallery(
    List<Uint8List> slidesImages, {
    String? albumName,
  }) async {
    return slidesImages.length;
  }
}

class RecordingCarouselExportService extends CardExportService {
  final List<List<Uint8List>> shareAllCalls = <List<Uint8List>>[];
  final List<List<Uint8List>> saveAllCalls = <List<Uint8List>>[];

  @override
  Future<void> shareAllSlides(
    List<Uint8List> slidesImages, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    shareAllCalls.add(List<Uint8List>.from(slidesImages));
  }

  @override
  Future<int> saveAllToGallery(
    List<Uint8List> slidesImages, {
    String? albumName,
  }) async {
    saveAllCalls.add(List<Uint8List>.from(slidesImages));
    return slidesImages.length;
  }
}
