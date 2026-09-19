import 'package:flutter/material.dart';

import '../templates/card_theme_config.dart';
import 'card_canvas.dart';

/// Full-screen pinch-to-zoom inspect of the live card canvas.
///
/// Renders a separate [CardCanvas] so pan/zoom never mutates the exporter's
/// rasterization [RepaintBoundary].
class CardInspectModal extends StatefulWidget {
  const CardInspectModal({
    super.key,
    required this.text,
    required this.aspectRatio,
    required this.theme,
    required this.isProPurchased,
    this.author,
    this.authorHandle,
    this.currentSlideIndex,
    this.totalSlides,
  });

  final String text;
  final CardAspectRatio aspectRatio;
  final CardThemeConfig theme;
  final bool isProPurchased;
  final String? author;
  final String? authorHandle;
  final int? currentSlideIndex;
  final int? totalSlides;

  /// Opens a dimmed full-screen inspect route.
  static Future<void> show({
    required BuildContext context,
    required String text,
    required CardAspectRatio aspectRatio,
    required CardThemeConfig theme,
    required bool isProPurchased,
    String? author,
    String? authorHandle,
    int? currentSlideIndex,
    int? totalSlides,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close card preview',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SizedBox.expand(
          child: CardInspectModal(
            key: const Key('card-inspect-modal'),
            text: text,
            aspectRatio: aspectRatio,
            theme: theme,
            isProPurchased: isProPurchased,
            author: author,
            authorHandle: authorHandle,
            currentSlideIndex: currentSlideIndex,
            totalSlides: totalSlides,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<CardInspectModal> createState() => _CardInspectModalState();
}

class _CardInspectModalState extends State<CardInspectModal> {
  final GlobalKey _canvasKey = GlobalKey();

  void _close() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('card-inspect-dismiss'),
      direction: DismissDirection.down,
      confirmDismiss: (_) async {
        _close();
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                  child: InteractiveViewer(
                    key: const Key('card-inspect-viewer'),
                    minScale: 0.8,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: GestureDetector(
                      onTap: () {},
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: CardCanvas(
                            canvasKey: _canvasKey,
                            text: widget.text,
                            aspectRatio: widget.aspectRatio,
                            theme: widget.theme,
                            author: widget.author,
                            authorHandle: widget.authorHandle,
                            isProPurchased: widget.isProPurchased,
                            currentSlideIndex: widget.currentSlideIndex,
                            totalSlides: widget.totalSlides,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  key: const Key('card-inspect-close'),
                  tooltip: 'Close preview',
                  onPressed: _close,
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
