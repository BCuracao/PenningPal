import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../paywall/paywall_bottom_sheet.dart';
import '../../paywall/paywall_provider.dart';
import '../models/carousel_deck.dart';
import '../render/card_export_service.dart';
import '../render/card_rasterizer.dart';
import '../render/carousel_batch_exporter.dart';
import '../templates/card_theme_config.dart';
import 'card_canvas.dart';

/// Live preview + rasterize flow for visual quote / carousel cards.
class CardExporterScreen extends ConsumerStatefulWidget {
  const CardExporterScreen({
    super.key,
    this.text = '',
    this.author,
    this.rasterizer = const CardRasterizer(),
    this.exportService = const CardExportService(),
    this.batchExporter = const CarouselBatchExporter(),
  });

  /// Current scratchpad draft. Transformations are not written back.
  final String text;

  /// Optional handle shown in the card header / terminal title bar.
  final String? author;

  final CardRasterizer rasterizer;

  final CardExportService exportService;

  final CarouselBatchExporter batchExporter;

  @override
  ConsumerState<CardExporterScreen> createState() => _CardExporterScreenState();
}

class _CardExporterScreenState extends ConsumerState<CardExporterScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final Map<int, GlobalKey> _previewKeys = <int, GlobalKey>{};
  late final PageController _pageController;

  CardAspectRatio _aspect = CardAspectRatio.square;
  CardThemeConfig _theme = CardPresets.minimalClean;
  _ExportAction? _busy;
  Uint8List? _lastPngBytes;
  int _slideIndex = 0;
  int? _exportCurrent;
  int? _exportTotal;

  /// Most recent PNG capture, retained for tests.
  @visibleForTesting
  Uint8List? get debugLastPngBytes => _lastPngBytes;

  CarouselDeck get _deck => CarouselDeck.fromMarkdown(widget.text);

  String get _meterText {
    final deck = _deck;
    if (!deck.isCarousel) return widget.text;
    return deck.slideAt(_slideIndex);
  }

  bool get _isBusy => _busy != null;

  bool get _isPro => ref.watch(isProPurchasedProvider);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPro = _isPro;
    final titleStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      letterSpacing: -0.2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Card / Carousel', style: titleStyle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _AspectSwitch(
              selected: _aspect,
              onChanged: (next) => setState(() => _aspect = next),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildPreview(isPro),
            ),
          ),
          _CharacterMeter(text: _meterText),
          _WatermarkToggle(
            isPro: isPro,
            removeWatermark: !_theme.showWatermark,
            onChanged: _onRemoveWatermarkChanged,
          ),
          _TemplateCarousel(
            selected: _theme,
            isPro: isPro,
            onSelected: _onThemeSelected,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportCurrent != null && _exportTotal != null)
                    _ExportProgress(
                      current: _exportCurrent!,
                      total: _exportTotal!,
                    ),
                  _ExportActionBar(
                    busy: _busy,
                    isCarousel: _deck.isCarousel,
                    slideCount: _deck.totalSlides,
                    onShare: _shareCard,
                    onSave: _saveToPhotos,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colors.surface,
    );
  }

  void _onThemeSelected(CardThemeConfig preset) {
    if (preset.isPremium && !ref.read(isProPurchasedProvider)) {
      unawaited(_promptUpgrade());
      return;
    }
    setState(() {
      _theme = preset.copyWith(showWatermark: _theme.showWatermark);
    });
  }

  void _onRemoveWatermarkChanged(bool remove) {
    if (!ref.read(isProPurchasedProvider)) {
      unawaited(_promptUpgrade());
      return;
    }
    setState(() {
      _theme = _theme.copyWith(showWatermark: !remove);
    });
  }

  Future<void> _promptUpgrade() async {
    await PaywallBottomSheet.show(context);
  }

  GlobalKey _previewKeyFor(int index) =>
      _previewKeys.putIfAbsent(index, GlobalKey.new);

  Widget _buildPreview(bool isPro) {
    final deck = _deck;
    if (!deck.isCarousel) {
      return _ScaledPreview(
        canvasKey: _canvasKey,
        text: widget.text,
        aspectRatio: _aspect,
        theme: _theme,
        author: widget.author,
        isProPurchased: isPro,
      );
    }

    return Column(
      children: [
        _CarouselBanner(
          label: deck.slideOfLabel(_slideIndex),
          onPrevious:
              _slideIndex > 0 ? () => unawaited(_goToPage(_slideIndex - 1)) : null,
          onNext: _slideIndex < deck.totalSlides - 1
              ? () => unawaited(_goToPage(_slideIndex + 1))
              : null,
        ),
        Expanded(
          child: PageView.builder(
            key: const Key('carousel-page-view'),
            controller: _pageController,
            itemCount: deck.totalSlides,
            onPageChanged: (index) => setState(() => _slideIndex = index),
            itemBuilder: (context, index) {
              return _ScaledPreview(
                canvasKey: _previewKeyFor(index),
                text: deck.slideAt(index),
                aspectRatio: _aspect,
                theme: _theme,
                author: widget.author,
                isProPurchased: isPro,
                currentSlideIndex: index,
                totalSlides: deck.totalSlides,
              );
            },
          ),
        ),
        _CarouselDots(
          count: deck.totalSlides,
          index: _slideIndex,
          onSelected: (index) => unawaited(_goToPage(index)),
        ),
      ],
    );
  }

  Future<void> _goToPage(int index) async {
    final deck = _deck;
    if (!deck.isCarousel) return;
    final next = index.clamp(0, deck.totalSlides - 1);
    if (!_pageController.hasClients) {
      setState(() => _slideIndex = next);
      return;
    }
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<List<Uint8List>> _rasterizeDeck(CarouselDeck deck) {
    return widget.batchExporter.renderDeck(
      deck,
      _theme,
      _aspect,
      ref.read(isProPurchasedProvider),
      context: context,
      author: widget.author,
      onProgress: (current, total) {
        if (!mounted) return;
        setState(() {
          _exportCurrent = current;
          _exportTotal = total;
        });
      },
    );
  }

  Future<void> _shareCard(BuildContext buttonContext) async {
    if (_isBusy) return;
    final origin = _shareOrigin(buttonContext);
    final deck = _deck;
    setState(() => _busy = _ExportAction.share);
    try {
      if (deck.isCarousel) {
        final images = await _rasterizeDeck(deck);
        if (!mounted) return;
        if (images.isEmpty) {
          _showToast('Could not capture card');
          return;
        }
        setState(() => _lastPngBytes = images.last);
        await widget.exportService.shareAllSlides(
          images,
          sharePositionOrigin: origin,
        );
      } else {
        final bytes = await widget.rasterizer.capturePng(_canvasKey);
        if (!mounted) return;
        if (bytes == null) {
          _showToast('Could not capture card');
          return;
        }
        setState(() => _lastPngBytes = bytes);
        await widget.exportService.shareCardImage(
          bytes,
          sharePositionOrigin: origin,
        );
      }
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
    } catch (_) {
      if (!mounted) return;
      _showToast('Could not share card');
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _exportCurrent = null;
          _exportTotal = null;
        });
      }
    }
  }

  Future<void> _saveToPhotos() async {
    if (_isBusy) return;
    final deck = _deck;
    setState(() => _busy = _ExportAction.save);
    try {
      if (deck.isCarousel) {
        final images = await _rasterizeDeck(deck);
        if (!mounted) return;
        if (images.isEmpty) {
          _showToast('Could not capture card');
          return;
        }
        setState(() => _lastPngBytes = images.last);
        final saved = await widget.exportService.saveAllToGallery(images);
        if (!mounted) return;
        if (saved == images.length && saved > 0) {
          unawaited(HapticFeedback.lightImpact());
          _showToast('$saved slides saved to Photos');
        } else if (saved == 0) {
          _showToast('Speichern nicht möglich');
        } else {
          unawaited(HapticFeedback.lightImpact());
          _showToast('$saved of ${images.length} slides saved to Photos');
        }
      } else {
        final bytes = await widget.rasterizer.capturePng(_canvasKey);
        if (!mounted) return;
        if (bytes == null) {
          _showToast('Could not capture card');
          return;
        }
        setState(() => _lastPngBytes = bytes);
        final saved = await widget.exportService.saveToGallery(bytes);
        if (!mounted) return;
        if (saved) {
          unawaited(HapticFeedback.lightImpact());
          _showToast('In Fotos gespeichert');
        } else {
          _showToast('Speichern nicht möglich');
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showToast('Speichern nicht möglich');
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _exportCurrent = null;
          _exportTotal = null;
        });
      }
    }
  }

  Rect? _shareOrigin(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }
}

enum _ExportAction { share, save }

class _ExportActionBar extends StatelessWidget {
  const _ExportActionBar({
    required this.busy,
    required this.isCarousel,
    required this.slideCount,
    required this.onShare,
    required this.onSave,
  });

  final _ExportAction? busy;
  final bool isCarousel;
  final int slideCount;
  final ValueChanged<BuildContext> onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: isCarousel ? 11.5 : 13,
    );
    final isBusy = busy != null;
    final shareLabel = busy == _ExportAction.share
        ? (isCarousel ? 'Exporting…' : 'Sharing…')
        : (isCarousel
            ? 'Share Carousel ($slideCount Slides)'
            : 'Share Image');
    final saveLabel = busy == _ExportAction.save
        ? (isCarousel ? 'Exporting…' : 'Saving…')
        : (isCarousel ? 'Save All ($slideCount Slides)' : 'Save Image');

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (buttonContext) {
                return FilledButton.icon(
                  key: const Key('share-card-png'),
                  onPressed: isBusy ? null : () => onShare(buttonContext),
                  icon: busy == _ExportAction.share
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share, size: 18),
                  label: Text(
                    shareLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              key: const Key('save-card-gallery'),
              onPressed: isBusy ? null : onSave,
              icon: busy == _ExportAction.save
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_outlined, size: 18),
              label: Text(
                saveLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scales the 1080px canvas into the available preview slot without clipping
/// or mutating the [RepaintBoundary] layout size used for rasterization.
class _ScaledPreview extends StatelessWidget {
  const _ScaledPreview({
    required this.canvasKey,
    required this.text,
    required this.aspectRatio,
    required this.theme,
    required this.author,
    required this.isProPurchased,
    this.currentSlideIndex,
    this.totalSlides,
  });

  final GlobalKey canvasKey;
  final String text;
  final CardAspectRatio aspectRatio;
  final CardThemeConfig theme;
  final String? author;
  final bool isProPurchased;
  final int? currentSlideIndex;
  final int? totalSlides;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            key: const Key('card-preview'),
            fit: BoxFit.contain,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: CardCanvas(
                canvasKey: canvasKey,
                text: text,
                aspectRatio: aspectRatio,
                theme: theme,
                author: author,
                isProPurchased: isProPurchased,
                currentSlideIndex: currentSlideIndex,
                totalSlides: totalSlides,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AspectSwitch extends StatelessWidget {
  const _AspectSwitch({
    required this.selected,
    required this.onChanged,
  });

  final CardAspectRatio selected;
  final ValueChanged<CardAspectRatio> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CardAspectRatio>(
      segments: [
        ButtonSegment<CardAspectRatio>(
          value: CardAspectRatio.square,
          label: Text(
            '1:1 Square',
            key: const Key('card-aspect-square'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          icon: const Icon(Icons.crop_square, size: 18),
        ),
        ButtonSegment<CardAspectRatio>(
          value: CardAspectRatio.story,
          label: Text(
            '9:16 Story',
            key: const Key('card-aspect-story'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          icon: const Icon(Icons.crop_portrait, size: 18),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (next) {
        if (next.isEmpty) return;
        onChanged(next.single);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}

class _CharacterMeter extends StatelessWidget {
  const _CharacterMeter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = text.trim().length;
    final style = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colors.onSurface.withValues(alpha: 0.55),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        '$count characters · type scales to fit',
        key: const Key('card-char-meter'),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

class _WatermarkToggle extends StatelessWidget {
  const _WatermarkToggle({
    required this.isPro,
    required this.removeWatermark,
    required this.onChanged,
  });

  final bool isPro;
  final bool removeWatermark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      key: const Key('remove-watermark-toggle'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      title: Text(
        'Remove Watermark',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      secondary: Icon(
        isPro ? Icons.water_drop_outlined : Icons.lock_outline,
        key: isPro
            ? const Key('watermark-unlocked')
            : const Key('watermark-lock'),
        size: 20,
        color: colors.onSurface.withValues(alpha: 0.6),
      ),
      value: isPro && removeWatermark,
      onChanged: onChanged,
    );
  }
}

class _TemplateCarousel extends StatelessWidget {
  const _TemplateCarousel({
    required this.selected,
    required this.isPro,
    required this.onSelected,
  });

  final CardThemeConfig selected;
  final bool isPro;
  final ValueChanged<CardThemeConfig> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        key: const Key('card-template-carousel'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: CardPresets.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = CardPresets.all[index];
          final isSelected = preset.id == selected.id;
          return _TemplateChip(
            preset: preset,
            selected: isSelected,
            locked: preset.isPremium && !isPro,
            onTap: () => onSelected(preset),
          );
        },
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.preset,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final CardThemeConfig preset;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.55)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('card-template-${preset.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: preset.backgroundColor,
                  gradient: preset.backgroundGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: preset.accentColor, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                preset.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.lock_outline,
                  key: Key('theme-lock-${preset.id}'),
                  size: 14,
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselBanner extends StatelessWidget {
  const _CarouselBanner({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        children: [
          IconButton(
            key: const Key('carousel-prev'),
            tooltip: 'Previous slide',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              label,
              key: const Key('carousel-slide-banner'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: const Key('carousel-next'),
            tooltip: 'Next slide',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({
    required this.count,
    required this.index,
    required this.onSelected,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        key: const Key('carousel-dots'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                key: Key('carousel-dot-$i'),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index
                        ? colors.primary
                        : colors.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          LinearProgressIndicator(
            key: const Key('carousel-export-progress'),
            value: total <= 0 ? 0 : current / total,
          ),
          const SizedBox(height: 6),
          Text(
            'Exporting slide $current of $total...',
            key: const Key('carousel-export-status'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
