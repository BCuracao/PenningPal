import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'card_rasterizer.dart';

/// Resolves the on-device cache directory used for temporary PNG files.
typedef TemporaryDirectoryGetter = Future<Directory> Function();

/// Writes a PNG buffer into the device photo library / Camera Roll.
typedef PutImageBytes = Future<void> Function(
  Uint8List bytes, {
  String? album,
  String name,
});

/// Checks or requests gallery access. Returns `false` when the user refuses.
typedef GalleryAccessCheck = Future<bool> Function({bool toAlbum});

/// Opens the native share sheet for one or more files.
typedef ShareCardFiles = Future<void> Function(
  List<XFile> files, {
  String text,
  Rect? sharePositionOrigin,
});

/// Local-only PNG export: temp cache, Camera Roll, and the system share sheet.
///
/// Never uploads bytes. Gallery permission failures return `false` instead of
/// throwing so the UI can stay up when the user denies Photos access.
class CardExportService {
  const CardExportService({
    this.temporaryDirectory,
    this.putImageBytes,
    this.hasGalleryAccess,
    this.requestGalleryAccess,
    this.shareFiles,
  });

  /// Album created in Photos when saving a card.
  static const String defaultAlbumName = 'PenningPal';

  /// Stable stem used when a caller-supplied filename is empty or illegal.
  static const String defaultFileStem = 'clean_canvas_card';

  /// Override for tests. Defaults to [getTemporaryDirectory].
  final TemporaryDirectoryGetter? temporaryDirectory;

  /// Override for tests. Defaults to [Gal.putImageBytes].
  final PutImageBytes? putImageBytes;

  /// Override for tests. Defaults to [Gal.hasAccess].
  final GalleryAccessCheck? hasGalleryAccess;

  /// Override for tests. Defaults to [Gal.requestAccess].
  final GalleryAccessCheck? requestGalleryAccess;

  /// Override for tests. Defaults to [SharePlus.instance.share].
  final ShareCardFiles? shareFiles;

  /// Timestamped PNG name, e.g. `clean_canvas_20260918_150407.png`.
  static String generateFilename({DateTime? now}) {
    final stamp = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'clean_canvas_${stamp.year}${two(stamp.month)}${two(stamp.day)}_'
        '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}.png';
  }

  /// Unique name for slide [index] (0-based) inside a carousel export.
  static String generateSlideFilename({
    required int index,
    required int total,
    DateTime? now,
  }) {
    final stamp = generateFilename(now: now).replaceFirst('.png', '');
    return '${stamp}_slide_${index + 1}_of_$total.png';
  }

  /// Drops path components and illegal characters; always ends in `.png`.
  static String sanitizeFilename(String filename) {
    var name = filename.trim().replaceAll('\\', '/');
    if (name.contains('/')) {
      name = name.split('/').last;
    }

    var stem = name;
    if (stem.toLowerCase().endsWith('.png')) {
      stem = stem.substring(0, stem.length - 4);
    }

    stem = stem.replaceAll(RegExp(r'[^\w\-]+'), '_');
    stem = stem.replaceAll(RegExp(r'_+'), '_');
    stem = stem.replaceAll(RegExp(r'^_|_$'), '');
    if (stem.isEmpty) stem = defaultFileStem;
    return '$stem.png';
  }

  /// True when [byteData] starts with the PNG magic number and is non-empty.
  static bool isValidPngBytes(Uint8List byteData) {
    const signature = CardRasterizer.pngSignature;
    if (byteData.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (byteData[i] != signature[i]) return false;
    }
    return true;
  }

  /// Throws [ArgumentError] for empty or non-PNG buffers.
  static void ensureValidPngBytes(Uint8List byteData) {
    if (byteData.isEmpty) {
      throw ArgumentError.value(byteData, 'byteData', 'PNG buffer is empty');
    }
    if (!isValidPngBytes(byteData)) {
      throw ArgumentError.value(
        byteData,
        'byteData',
        'Not a valid PNG buffer',
      );
    }
  }

  /// Writes [byteData] into the app cache and returns the file.
  Future<File> saveImageTemporarily(Uint8List byteData, String filename) async {
    ensureValidPngBytes(byteData);
    final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/${sanitizeFilename(filename)}');
    await file.writeAsBytes(byteData, flush: true);
    return file;
  }

  /// Saves [byteData] to the gallery. Returns `false` on denial or failure.
  Future<bool> saveToGallery(
    Uint8List byteData, {
    String? albumName,
    String? filename,
  }) async {
    if (!isValidPngBytes(byteData)) return false;
    final album = albumName ?? defaultAlbumName;
    final toAlbum = album.isNotEmpty;
    try {
      final allowed = await _ensureGalleryAccess(toAlbum: toAlbum);
      if (!allowed) return false;
      final name = _galleryName(filename ?? generateFilename());
      await _putBytes(byteData, album: album, name: name);
      return true;
    } on GalException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Writes each slide to temp storage and opens one share sheet for all.
  Future<void> shareAllSlides(
    List<Uint8List> slidesImages, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    if (slidesImages.isEmpty) return;
    final files = <XFile>[];
    final now = DateTime.now();
    for (var i = 0; i < slidesImages.length; i++) {
      final filename = generateSlideFilename(
        index: i,
        total: slidesImages.length,
        now: now,
      );
      final file = await saveImageTemporarily(slidesImages[i], filename);
      files.add(XFile(file.path, mimeType: 'image/png'));
    }
    final share = shareFiles ?? _shareXFiles;
    await share(
      files,
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Saves each slide sequentially to the photo library.
  ///
  /// Returns the number of slides that landed in the gallery. Permission
  /// denial or a corrupt buffer counts as an unsaved slide rather than a
  /// throw.
  Future<int> saveAllToGallery(
    List<Uint8List> slidesImages, {
    String? albumName,
  }) async {
    var saved = 0;
    final now = DateTime.now();
    for (var i = 0; i < slidesImages.length; i++) {
      final ok = await saveToGallery(
        slidesImages[i],
        albumName: albumName,
        filename: generateSlideFilename(
          index: i,
          total: slidesImages.length,
          now: now,
        ),
      );
      if (ok) saved += 1;
    }
    return saved;
  }

  /// Writes a temp PNG and opens the native share sheet.
  Future<void> shareCardImage(
    Uint8List byteData, {
    String text = '',
    Rect? sharePositionOrigin,
  }) async {
    final file = await saveImageTemporarily(byteData, generateFilename());
    final xFile = XFile(file.path, mimeType: 'image/png');
    final share = shareFiles ?? _shareXFiles;
    await share(
      [xFile],
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<bool> _ensureGalleryAccess({required bool toAlbum}) async {
    try {
      final hasAccess =
          await (hasGalleryAccess ?? Gal.hasAccess)(toAlbum: toAlbum);
      if (hasAccess) return true;
      return await (requestGalleryAccess ?? Gal.requestAccess)(toAlbum: toAlbum);
    } catch (_) {
      return false;
    }
  }

  Future<void> _putBytes(
    Uint8List bytes, {
    required String album,
    required String name,
  }) async {
    final put = putImageBytes;
    if (put != null) {
      await put(bytes, album: album, name: name);
      return;
    }
    await Gal.putImageBytes(bytes, album: album, name: name);
  }

  /// Native share sheet. Equivalent to `Share.shareXFiles([XFile(path)])`.
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

  /// [Gal.putImageBytes] expects a stem without the `.png` suffix.
  static String _galleryName(String filename) {
    final sanitized = sanitizeFilename(filename);
    if (sanitized.toLowerCase().endsWith('.png')) {
      return sanitized.substring(0, sanitized.length - 4);
    }
    return sanitized;
  }
}
