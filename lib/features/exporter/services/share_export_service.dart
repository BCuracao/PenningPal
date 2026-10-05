import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../render/card_export_service.dart';
import '../render/linkedin_pdf_exporter.dart';

/// Opens the OS share sheet for a rendered card. Files stay in the temp cache.
class ShareExportService {
  const ShareExportService({
    this.temporaryDirectory,
    this.shareFiles,
    this.pdfExporter,
  });

  /// Override for tests. Defaults to [getTemporaryDirectory].
  final TemporaryDirectoryGetter? temporaryDirectory;

  /// Override for tests. Defaults to [SharePlus.instance.share].
  final ShareCardFiles? shareFiles;

  /// Override for tests. Defaults to [LinkedInPdfExporter].
  final LinkedInPdfExporter? pdfExporter;

  /// Writes [pngBytes] to a temp PNG and shares that file.
  ///
  /// Equivalent to `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.
  Future<void> shareSingleCard(
    Uint8List pngBytes, {
    Rect? sharePositionOrigin,
  }) async {
    final file = await _writeTempPng(pngBytes);
    final share = shareFiles ?? _shareXFiles;
    await share(
      [XFile(file.path, mimeType: 'image/png')],
      text: '',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Renders [slidePngs] into one multi-page PDF and shares that file.
  ///
  /// Carousel recipients (LinkedIn, AirDrop, Files, messaging) receive the
  /// PDF directly instead of a stack of PNGs.
  Future<void> shareCarouselPdf(
    List<Uint8List> slidePngs, {
    Rect? sharePositionOrigin,
  }) async {
    if (slidePngs.isEmpty) return;
    final exporter = pdfExporter ??
        LinkedInPdfExporter(temporaryDirectory: temporaryDirectory);
    final file = await exporter.generatePdfCarousel(slidePngs);
    final share = shareFiles ?? _shareXFiles;
    await share(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: '',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<File> _writeTempPng(Uint8List pngBytes) async {
    CardExportService.ensureValidPngBytes(pngBytes);
    final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(
      '${directory.path}/${CardExportService.generateFilename()}',
    );
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  Future<void> _shareXFiles(
    List<XFile> files, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: text.isEmpty ? null : text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
