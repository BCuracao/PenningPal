import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Converts a [RepaintBoundary] into a PNG byte buffer.
///
/// Always rasterizes with a fixed [pixelRatio] (default `3.0`) so output
/// sharpness does not depend on the device's physical DPI.
class CardRasterizer {
  const CardRasterizer();

  /// Default retina multiplier. `3.0` on a 1080×1080 canvas yields 3240² px.
  static const double defaultPixelRatio = 3.0;

  /// PNG magic number (`\x89PNG\r\n\x1a\n`) used by tests and callers.
  static const List<int> pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// Captures [boundaryKey]'s current layer as PNG bytes.
  ///
  /// Returns `null` when the key is unmounted, the render object is not a
  /// [RenderRepaintBoundary], or encoding fails.
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = defaultPixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) return null;

    var boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    if (await _needsPaint(boundary)) {
      await waitForNextFrame();
      boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
    }

    ui.Image? image;
    try {
      image = await boundary
          .toImage(pixelRatio: pixelRatio)
          .timeout(const Duration(seconds: 8));
      final byteData = await image
          .toByteData(format: ui.ImageByteFormat.png)
          .timeout(const Duration(seconds: 8));
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// `RenderObject.debugNeedsPaint` is an assert-only getter; reading it in
  /// release would throw. Gate the check so rasterization still works in
  /// profile/release while honoring frame readiness in debug.
  Future<bool> _needsPaint(RenderRepaintBoundary boundary) async {
    var needsPaint = false;
    assert(() {
      needsPaint = boundary.debugNeedsPaint;
      return true;
    }());
    return needsPaint;
  }

  /// Waits until the next frame has been built, laid out, and painted.
  ///
  /// Bailing out with a zero delay while the scheduler is idle returns before
  /// that frame. Carousel export would then snapshot the previous slide once
  /// for every page. Always schedule a frame and resume from its post-frame
  /// callback.
  static Future<void> waitForNextFrame() async {
    final binding = SchedulerBinding.instance;
    final completer = Completer<void>();
    binding.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    binding.scheduleFrame();
    try {
      await completer.future.timeout(const Duration(milliseconds: 250));
    } on TimeoutException {
      // No frame landed; the caller will attempt capture anyway.
    }
  }
}
