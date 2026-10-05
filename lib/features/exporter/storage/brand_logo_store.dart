import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a brand-kit logo into application-support storage.
///
/// The file stays on device and is never uploaded.
class BrandLogoStore {
  const BrandLogoStore({
    this.picker,
    this.supportDirectory,
    this.pickImage,
  });

  static const String folderName = 'brand_logos';

  final ImagePicker? picker;

  /// Override for tests. Defaults to [getApplicationSupportDirectory].
  final Future<Directory> Function()? supportDirectory;

  /// Override for tests. Defaults to [ImagePicker.pickImage].
  final Future<XFile?> Function()? pickImage;

  Future<String?> pickFromGallery() async {
    final xfile = await (pickImage ?? _defaultPick)();
    if (xfile == null) return null;
    return persistLocalCopy(xfile.path);
  }

  Future<XFile?> _defaultPick() {
    final plugin = picker ?? ImagePicker();
    return plugin.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 92,
      requestFullMetadata: false,
    );
  }

  Future<String> persistLocalCopy(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError.value(sourcePath, 'sourcePath', 'File does not exist');
    }
    if (isManagedPath(sourcePath)) return sourcePath;

    final folder = await _folder();
    final ext = _extensionOf(sourcePath);
    final dest = File(
      '${folder.path}/logo_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await source.copy(dest.path);
    return dest.path;
  }

  static bool isManagedPath(String path) {
    return path.contains(
          '${Platform.pathSeparator}$folderName${Platform.pathSeparator}',
        ) ||
        path.contains('/$folderName/');
  }

  Future<Directory> _folder() async {
    final root = await (supportDirectory ?? getApplicationSupportDirectory)();
    final folder = Directory('${root.path}${Platform.pathSeparator}$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.png';
    final ext = path.substring(dot).toLowerCase();
    if (ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp') {
      return ext;
    }
    return '.png';
  }

  /// Deletes [path] only when it lives in this store's folder.
  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !isManagedPath(path)) return;
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      debugPrint('BrandLogoStore.deleteIfManaged: $error\n$stackTrace');
    }
  }
}
