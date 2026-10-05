import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/carousel_deck.dart';
import '../models/slide_role.dart';
import '../presentation/card_canvas.dart';
import '../templates/card_theme_config.dart';
import 'card_rasterizer.dart';

/// Sequentially rasterizes every slide in a [CarouselDeck] at identical
/// social dimensions and a fixed high DPI.
///
/// Each frame is presented off-screen, allowed to paint, then captured
/// before the next slide is mounted so we never hold more than one
/// [dart:ui.Image] at a time.
class CarouselBatchExporter {
  const CarouselBatchExporter({this.rasterizer = const CardRasterizer()});

  final CardRasterizer rasterizer;

  /// Renders [deck] into PNG buffers using an off-screen overlay.
  ///
  /// [isProPurchased] is forwarded to [CardCanvas] so watermark / theme
  /// enforcement matches the live preview.
  Future<List<Uint8List>> renderDeck(
    CarouselDeck deck,
    CardThemeConfig config,
    CardAspectRatio ratio,
    bool isProPurchased, {
    required BuildContext context,
    String? author,
    String? authorHandle,
    List<SlideRole>? slideRoles,
    String? avatarPath,
    String? avatarInitials,
    Color? avatarColor,
    String? fontPairingId,
    String? logoPath,
    bool showQrCode = false,
    String? qrDestination,
    void Function(int current, int total)? onProgress,
  }) async {
    SlideRole roleAt(int index) {
      if (slideRoles != null && index >= 0 && index < slideRoles.length) {
        return slideRoles[index];
      }
      return SlideRoles.detect(index: index, totalSlides: deck.totalSlides);
    }

    final presenter = _SlidePresenter(
      text: deck.slideAt(0),
      index: 0,
      role: roleAt(0),
    );
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      opaque: false,
      builder: (_) {
        return ListenableBuilder(
          listenable: presenter,
          builder: (context, _) {
            return Positioned(
              left: -(ratio.width + 64),
              top: 0,
              child: IgnorePointer(
                child: CardCanvas(
                  canvasKey: boundaryKey,
                  text: presenter.text,
                  aspectRatio: ratio,
                  theme: config,
                  author: author,
                  authorHandle: authorHandle,
                  isProPurchased: isProPurchased,
                  currentSlideIndex: presenter.index,
                  totalSlides: deck.totalSlides,
                  slideRole: presenter.role,
                  avatarPath: avatarPath,
                  avatarInitials: avatarInitials ?? '',
                  avatarColor: avatarColor,
                  fontPairingId: fontPairingId,
                  logoPath: logoPath,
                  showQrCode: showQrCode,
                  qrDestination: qrDestination,
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(entry);
    try {
      if (config.hasCustomBackground) {
        final file = File(config.customBackgroundImagePath!);
        if (await file.exists() && context.mounted) {
          try {
            await precacheImage(FileImage(file), context);
          } catch (_) {
            // Capture still proceeds; Image.file errorBuilder keeps layout.
          }
        }
      }
      if (logoPath != null && logoPath.isNotEmpty) {
        final logo = File(logoPath);
        if (await logo.exists() && context.mounted) {
          try {
            await precacheImage(FileImage(logo), context);
          } catch (_) {
            // Capture still proceeds; Image.file errorBuilder keeps layout.
          }
        }
      }
      await _waitForFrame();
      return await captureSlides(
        deck: deck,
        boundaryKey: boundaryKey,
        onProgress: onProgress,
        presentSlide: (index, text) async {
          presenter.update(index, text, roleAt(index));
          // First frame rebuilds the off-screen card. The second paints it
          // so capture cannot reuse the previous slide's layer.
          await _waitForFrame();
          await _waitForFrame();
        },
      );
    } finally {
      entry.remove();
    }
  }

  /// Frame-by-frame capture used by [renderDeck] and unit tests.
  ///
  /// [presentSlide] must rebuild the off-screen [CardCanvas] bound to
  /// [boundaryKey] and return only after that frame has been scheduled.
  Future<List<Uint8List>> captureSlides({
    required CarouselDeck deck,
    required GlobalKey boundaryKey,
    required Future<void> Function(int index, String text) presentSlide,
    void Function(int current, int total)? onProgress,
  }) async {
    final slides = deck.slides.isEmpty ? const [''] : deck.slides;
    final images = <Uint8List>[];
    for (var i = 0; i < slides.length; i++) {
      onProgress?.call(i + 1, slides.length);
      await presentSlide(i, slides[i]);
      await _waitForFrame();
      final bytes = await rasterizer.capturePng(boundaryKey);
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'Failed to rasterize slide ${i + 1} of ${slides.length}',
        );
      }
      images.add(bytes);
    }
    return images;
  }

  Future<void> _waitForFrame() => CardRasterizer.waitForNextFrame();
}

class _SlidePresenter extends ChangeNotifier {
  _SlidePresenter({
    required this.text,
    required this.index,
    required this.role,
  });

  String text;
  int index;
  SlideRole role;

  void update(int newIndex, String newText, SlideRole newRole) {
    if (index == newIndex && text == newText && role == newRole) return;
    index = newIndex;
    text = newText;
    role = newRole;
    notifyListeners();
  }
}
