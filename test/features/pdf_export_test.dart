import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clean_canvas/features/exporter/render/card_export_service.dart';
import 'package:clean_canvas/features/exporter/render/linkedin_pdf_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

/// 1×1 PNG used as a stand-in for rasterized 1080px slides.
final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  group('LinkedInPdfExporter', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('penningpal_pdf_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('page format is a marginless 1080×1080 square', () {
      expect(LinkedInPdfExporter.pageFormat.width, 1080);
      expect(LinkedInPdfExporter.pageFormat.height, 1080);
      expect(LinkedInPdfExporter.pageFormat.marginLeft, 0);
      expect(LinkedInPdfExporter.pageFormat.marginTop, 0);
      expect(LinkedInPdfExporter.pageFormat.marginRight, 0);
      expect(LinkedInPdfExporter.pageFormat.marginBottom, 0);
      expect(LinkedInPdfExporter.pageFormat, isA<PdfPageFormat>());
    });

    test('compiles a 3-slide PNG array into a valid 3-page PDF', () async {
      final exporter = LinkedInPdfExporter(
        temporaryDirectory: () async => tempDir,
      );

      final file = await exporter.generatePdfCarousel(
        [_tinyPng, _tinyPng, _tinyPng],
        filename: 'linkedin-carousel.pdf',
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, endsWith('linkedin-carousel.pdf'));
      final bytes = await file.readAsBytes();
      expect(LinkedInPdfExporter.isPdf(Uint8List.fromList(bytes)), isTrue);
      expect(LinkedInPdfExporter.countPages(Uint8List.fromList(bytes)), 3);
    });

    test('rejects an empty slide list', () async {
      final exporter = LinkedInPdfExporter(
        temporaryDirectory: () async => tempDir,
      );
      await expectLater(
        exporter.generatePdfCarousel(const []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sanitizeFilename always ends in .pdf', () {
      expect(LinkedInPdfExporter.sanitizeFilename('Deck!.PDF'), 'Deck.pdf');
      expect(LinkedInPdfExporter.sanitizeFilename('../x'), 'x.pdf');
      expect(LinkedInPdfExporter.sanitizeFilename('   '), 'carousel.pdf');
    });
  });

  group('CardExportService.shareLinkedInPdf', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('penningpal_pdf_share_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('shares a PDF xfile with application/pdf', () async {
      final shared = <List<XFile>>[];
      final service = CardExportService(
        temporaryDirectory: () async => tempDir,
        shareFiles: (files, {text = '', sharePositionOrigin}) async {
          shared.add(files);
        },
      );

      await service.shareLinkedInPdf([_tinyPng, _tinyPng]);

      expect(shared, hasLength(1));
      expect(shared.single, hasLength(1));
      expect(shared.single.single.mimeType, 'application/pdf');
      expect(shared.single.single.path, endsWith('.pdf'));
      expect(File(shared.single.single.path).existsSync(), isTrue);
    });
  });
}
