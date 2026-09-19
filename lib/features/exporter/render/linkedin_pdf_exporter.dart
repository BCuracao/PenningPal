import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'card_export_service.dart';
import 'card_rasterizer.dart';

/// On-device LinkedIn document carousel: one 1080×1080 pt page per slide PNG.
///
/// Uses the pure-Dart `pdf` package. Nothing is uploaded.
class LinkedInPdfExporter {
  const LinkedInPdfExporter({this.temporaryDirectory});

  /// Square LinkedIn document page. Image fills the page with zero margins.
  static const PdfPageFormat pageFormat = PdfPageFormat(
    1080,
    1080,
    marginAll: 0,
  );

  static const String defaultFilename = 'carousel.pdf';

  /// Override for tests. Defaults to [getTemporaryDirectory].
  final TemporaryDirectoryGetter? temporaryDirectory;

  /// Compiles [slidePngs] into a multi-page PDF and writes it to temp storage.
  Future<File> generatePdfCarousel(
    List<Uint8List> slidePngs, {
    String filename = defaultFilename,
  }) async {
    if (slidePngs.isEmpty) {
      throw ArgumentError.value(slidePngs, 'slidePngs', 'No slides to export');
    }
    for (var i = 0; i < slidePngs.length; i++) {
      _ensurePng(slidePngs[i], i);
    }

    final doc = pw.Document();
    for (final png in slidePngs) {
      final image = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.SizedBox(
              width: pageFormat.width,
              height: pageFormat.height,
              child: pw.Image(
                image,
                fit: pw.BoxFit.cover,
                width: pageFormat.width,
                height: pageFormat.height,
              ),
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/${sanitizeFilename(filename)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Drops path components and illegal characters; always ends in `.pdf`.
  static String sanitizeFilename(String filename) {
    var name = filename.trim().replaceAll('\\', '/');
    if (name.contains('/')) {
      name = name.split('/').last;
    }

    var stem = name;
    if (stem.toLowerCase().endsWith('.pdf')) {
      stem = stem.substring(0, stem.length - 4);
    }

    stem = stem.replaceAll(RegExp(r'[^\w\-]+'), '_');
    stem = stem.replaceAll(RegExp(r'_+'), '_');
    stem = stem.replaceAll(RegExp(r'^_|_$'), '');
    if (stem.isEmpty) stem = 'carousel';
    return '$stem.pdf';
  }

  /// True when [bytes] start with `%PDF`.
  static bool isPdf(Uint8List bytes) {
    const signature = [0x25, 0x50, 0x44, 0x46]; // %PDF
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// Counts `/Type /Page` objects (not the `/Pages` tree node).
  static int countPages(Uint8List pdfBytes) {
    final text = String.fromCharCodes(pdfBytes);
    return RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length;
  }

  static void _ensurePng(Uint8List bytes, int index) {
    if (bytes.isEmpty) {
      throw ArgumentError('Slide ${index + 1} PNG buffer is empty');
    }
    const signature = CardRasterizer.pngSignature;
    if (bytes.length < signature.length) {
      throw ArgumentError('Slide ${index + 1} is not a valid PNG');
    }
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        throw ArgumentError('Slide ${index + 1} is not a valid PNG');
      }
    }
  }
}
