import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../templates/card_theme_config.dart';
import 'card_rasterizer.dart';

/// On-device photo backdrop picker. Images stay in application-support
/// storage and are never uploaded.
class PhotoBackdropStore {
  const PhotoBackdropStore({
    this.picker,
    this.supportDirectory,
    this.pickImage,
  });

  static const String folderName = 'photo_backdrops';

  final ImagePicker? picker;

  /// Override for tests. Defaults to [getApplicationSupportDirectory].
  final Future<Directory> Function()? supportDirectory;

  /// Override for tests. Defaults to [ImagePicker.pickImage].
  final Future<XFile?> Function()? pickImage;

  /// Opens the system photo library and copies the pick into app storage.
  Future<String?> pickFromGallery() async {
    final xfile = await (pickImage ?? _defaultPick)();
    if (xfile == null) return null;
    return persistLocalCopy(xfile.path);
  }

  Future<XFile?> _defaultPick() {
    final plugin = picker ?? ImagePicker();
    return plugin.pickImage(
      source: ImageSource.gallery,
      maxWidth: CardAspectRatio.square.width * CardRasterizer.defaultPixelRatio,
      maxHeight: CardAspectRatio.story.height * CardRasterizer.defaultPixelRatio,
      imageQuality: 92,
      requestFullMetadata: false,
    );
  }

  /// Copies [sourcePath] into `photo_backdrops/` under application support.
  Future<String> persistLocalCopy(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError.value(sourcePath, 'sourcePath', 'File does not exist');
    }
    if (isManagedPath(sourcePath)) return sourcePath;

    final folder = await _folder();
    final ext = _extensionOf(sourcePath);
    final dest = File(
      '${folder.path}/backdrop_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await source.copy(dest.path);
    return dest.path;
  }

  /// Deletes [path] only when it lives in this store's folder.
  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !isManagedPath(path)) return;
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      debugPrint('PhotoBackdropStore.deleteIfManaged: $error\n$stackTrace');
    }
  }

  static bool isManagedPath(String path) {
    return path.contains('${Platform.pathSeparator}$folderName${Platform.pathSeparator}') ||
        path.contains('/$folderName/');
  }

  Future<Directory> _folder() async {
    final root = await (supportDirectory ?? getApplicationSupportDirectory)();
    final folder = Directory('${root.path}/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  static String _extensionOf(String path) {
    final slash = path.replaceAll('\\', '/');
    final name = slash.contains('/') ? slash.split('/').last : slash;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
    return allowed.contains(ext) ? ext : '.jpg';
  }
}
