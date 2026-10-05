import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/persistence/profile_storage.dart';
import '../../../core/persistence/settings_storage.dart';
import '../../paywall/paywall_bottom_sheet.dart';
import '../../paywall/paywall_provider.dart';
import '../../scratchpad/state/scratchpad_notifier.dart';
import '../models/brand_kit.dart';
import '../models/carousel_deck.dart';
import '../models/carousel_markdown.dart';
import '../models/font_pairing.dart';
import '../models/slide_role.dart';
import '../render/card_export_service.dart';
import '../render/card_rasterizer.dart';
import '../render/carousel_batch_exporter.dart';
import '../render/photo_backdrop_store.dart';
import '../services/share_export_service.dart';
import '../state/brand_kit_notifier.dart';
import '../state/card_settings.dart';
import '../templates/card_theme_config.dart';
import 'brand_color_picker_sheet.dart';
import 'brand_profile_sheet.dart';
import 'card_canvas.dart';
import 'card_customizer_controls.dart';
import 'card_inspect_modal.dart';
import 'widgets/brand_kit_carousel.dart';
import 'widgets/cta_qr_controls.dart';
import 'widgets/font_pairing_carousel.dart';
import 'widgets/slide_thumbnail_strip.dart';

/// Live preview + rasterize flow for visual quote / carousel cards.
class CardExporterScreen extends ConsumerStatefulWidget {
  const CardExporterScreen({
    super.key,
    this.text = '',
    this.author,
    this.authorHandle,
    this.rasterizer = const CardRasterizer(),
    this.exportService = const CardExportService(),
    this.batchExporter = const CarouselBatchExporter(),
    this.photoBackdropStore = const PhotoBackdropStore(),
    this.shareExportService = const ShareExportService(),
  });

  /// Scratchpad draft shown on the canvas. Structural slide edits write this
  /// buffer back to the active draft.
  final String text;

  /// Optional display name shown in the card header.
  final String? author;

  /// Optional @handle shown under the author name.
  final String? authorHandle;

  final CardRasterizer rasterizer;

  final CardExportService exportService;

  /// OS share sheet for a single PNG or a carousel PDF.
  final ShareExportService shareExportService;

  final CarouselBatchExporter batchExporter;

  /// Local photo-library picker. Images stay on-device.
  final PhotoBackdropStore photoBackdropStore;

  @override
  ConsumerState<CardExporterScreen> createState() => _CardExporterScreenState();
}

class _CardExporterScreenState extends ConsumerState<CardExporterScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final Map<int, GlobalKey> _previewKeys = <int, GlobalKey>{};
  final Map<int, SlideRole> _roleOverrides = <int, SlideRole>{};
  late final PageController _pageController;
  late String _markdown;

  CardAspectRatio _aspect = CardAspectRatio.square;
  CardThemeConfig _theme = CardPresets.minimalClean;
  _ExportAction? _busy;
  Uint8List? _lastPngBytes;
  int _slideIndex = 0;
  int? _exportCurrent;
  int? _exportTotal;
  bool _appliedProfileTheme = false;
  String? _fontPairingId;
  String? _logoPath;
  String? _activeKitId;
  bool _showQrCode = false;
  late final TextEditingController _qrController;

  /// Most recent PNG capture, retained for tests.
  @visibleForTesting
  Uint8List? get debugLastPngBytes => _lastPngBytes;

  CarouselDeck get _deck => CarouselDeck.fromMarkdown(_markdown);

  String get _meterText {
    final deck = _deck;
    if (!deck.isCarousel) return _markdown;
    return deck.slideAt(_slideIndex);
  }

  bool get _isBusy => _busy != null;

  /// Actual store entitlement — drives lock icons and Pro chrome.
  bool get _isProPurchased => ref.watch(isProPurchasedProvider);

  /// Action / render gate. True when purchased or demo bypass is on.
  bool get _canAccessPro => ref.watch(canAccessProFeatureProvider);

  @override
  void initState() {
    super.initState();
    _markdown = widget.text;
    _pageController = PageController();
    _qrController = TextEditingController();
    _qrController.addListener(_onQrChanged);
  }

  @override
  void didUpdateWidget(covariant CardExporterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _markdown) {
      _markdown = widget.text;
      _roleOverrides.clear();
      _slideIndex = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedProfileTheme) return;
    _appliedProfileTheme = true;
    final settings = ref.read(cardSettingsProvider);
    final resolved = _themeFromSettings(settings);
    if (!resolved.isPremium || ref.read(canAccessProFeatureProvider)) {
      _theme = resolved.withExporterChrome(_theme);
    }
  }

  void _onQrChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _qrController.removeListener(_onQrChanged);
    _qrController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  CardThemeConfig _themeFromSettings(CardSettings settings) {
    return CardPresets.resolve(
      settings.defaultThemeId,
      customBackground: Color(settings.customBackgroundColor),
      customText: Color(settings.customTextColor),
    );
  }

  String? get _authorName {
    final name = ref.read(cardSettingsProvider).authorName.trim();
    if (name.isNotEmpty) return name;
    return widget.author;
  }

  String? get _authorHandle {
    return ref.read(cardSettingsProvider).formattedHandle ??
        widget.authorHandle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isProPurchased = _isProPurchased;
    final canAccessPro = _canAccessPro;
    final settings = ref.watch(cardSettingsProvider);
    final titleStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      letterSpacing: -0.2,
    );

    final story = _aspect == CardAspectRatio.story;

    return Scaffold(
      backgroundColor: colors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                _buildHeader(titleStyle),
                Expanded(
                  flex: story ? 68 : 42,
                  child: _buildHero(canAccessPro),
                ),
                Expanded(
                  flex: story ? 32 : 58,
                  child: _buildControlDeck(
                    isProPurchased: isProPurchased,
                    canAccessPro: canAccessPro,
                    settings: settings,
                  ),
                ),
              ],
            ),
            if (_isBusy)
              _ExportProgressOverlay(
                current: _exportCurrent,
                total: _exportTotal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TextStyle titleStyle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BackButton(key: Key('card-exporter-back')),
              Expanded(
                child: Text(
                  'Card / Carousel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: _AspectSwitch(
              selected: _aspect,
              onChanged: _isBusy
                  ? null
                  : (next) => setState(() {
                      _aspect = next;
                      _activeKitId = null;
                    }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlDeck({
    required bool isProPurchased,
    required bool canAccessPro,
    required CardSettings settings,
  }) {
    final deck = _deck;
    final safeIndex = deck.totalSlides <= 1
        ? 0
        : _slideIndex.clamp(0, deck.totalSlides - 1);

    return SingleChildScrollView(
      key: const Key('card-exporter-controls'),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SlideRoleSelector(
                role: _roleAt(safeIndex),
                onChanged: _isBusy ? null : _setRole,
              ),
            ),
          ),
          SlideThumbnailStrip(
            slides: deck.slides.isEmpty ? const [''] : deck.slides,
            activeIndex: safeIndex,
            enabled: !_isBusy,
            onSelect: (index) => unawaited(_goToPage(index)),
            onReorder: _reorderSlides,
            onDuplicate: _duplicateSlide,
            onDelete: _deleteSlide,
            onAdd: _addSlide,
          ),
          if (deck.isCarousel)
            _CarouselDots(
              count: deck.totalSlides,
              index: safeIndex,
              onSelected: _isBusy
                  ? null
                  : (index) => unawaited(_goToPage(index)),
            ),
          BrandKitCarousel(
            kits: ref.watch(brandKitsProvider),
            selectedId: _activeKitId,
            enabled: !_isBusy,
            onSelected: _applyBrandKit,
            onSave: () => unawaited(_saveBrandKit()),
            onDelete: (kit) => unawaited(_deleteBrandKit(kit)),
          ),
          FontPairingCarousel(
            selectedId: _fontPairingId,
            isProPurchased: isProPurchased,
            enabled: !_isBusy,
            onSelected: _onFontPairingSelected,
          ),
          _ProfileSwitcherPill(
            settings: settings,
            enabled: !_isBusy,
            onTap: () => unawaited(_openProfileSwitcher()),
          ),
          _TemplateCarousel(
            selected: _theme,
            isProPurchased: isProPurchased,
            onSelected: _onThemeSelected,
          ),
          _WatermarkToggle(
            isProPurchased: isProPurchased,
            canAccessPro: canAccessPro,
            removeWatermark: !_theme.showWatermark,
            onChanged: _onRemoveWatermarkChanged,
          ),
          CardCustomizerControls(
            theme: _theme,
            isProPurchased: isProPurchased,
            canAccessPro: canAccessPro,
            enabled: !_isBusy,
            onChanged: _onPhotoBackdropChanged,
            onPickPhoto: () => unawaited(_pickPhotoBackdrop()),
            onLockedFeature: () => unawaited(
              _promptUpgrade(
                highlight:
                    'Custom photo backdrops with blur and contrast scrim',
              ),
            ),
          ),
          if (_roleAt(safeIndex) == SlideRole.cta)
            CtaQrControls(
              controller: _qrController,
              showQrCode: _showQrCode,
              enabled: !_isBusy,
              onShowQrCode: (value) => setState(() => _showQrCode = value),
            ),
          _CharacterMeter(text: _meterText),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ExportActionBar(
              busy: _busy,
              isCarousel: deck.isCarousel,
              slideCount: deck.totalSlides,
              isProPurchased: isProPurchased,
              onShare: _shareCard,
              onSave: _saveToPhotos,
              onCopy: _copyCard,
              onExportPdf: _exportLinkedInPdf,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _onThemeSelected(CardThemeConfig preset) {
    if (preset.isPremium && !ref.read(canAccessProFeatureProvider)) {
      unawaited(
        _promptUpgrade(
          highlight: preset.isCustom
              ? 'Unlock Aurora, Editorial Cream, Neo-Brutal & Custom Hex themes'
              : null,
        ),
      );
      return;
    }
    if (preset.isCustom) {
      unawaited(_pickCustomColors());
      return;
    }
    setState(() {
      _theme = preset.withExporterChrome(_theme);
      _activeKitId = null;
    });
    unawaited(
      ref.read(cardSettingsProvider.notifier).update(defaultThemeId: preset.id),
    );
  }

  Future<void> _pickCustomColors() async {
    final settings = ref.read(cardSettingsProvider);
    final picked = await BrandColorPickerSheet.show(
      context,
      backgroundColor: _theme.isCustom
          ? _theme.backgroundColor
          : Color(settings.customBackgroundColor),
      textColor: _theme.isCustom
          ? _theme.textColor
          : Color(settings.customTextColor),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(cardSettingsProvider.notifier)
        .update(
          customBackgroundColor: picked.background.toARGB32(),
          customTextColor: picked.text.toARGB32(),
          defaultThemeId: CardPresets.customId,
        );
    if (!mounted) return;
    setState(() {
      _theme = CardPresets.custom(
        backgroundColor: picked.background,
        textColor: picked.text,
      ).withExporterChrome(_theme);
      _activeKitId = null;
    });
  }

  void _onRemoveWatermarkChanged(bool remove) {
    if (!ref.read(canAccessProFeatureProvider)) {
      unawaited(
        _promptUpgrade(highlight: "Remove 'Made with PenningPal' watermark"),
      );
      return;
    }
    setState(() {
      _theme = _theme.copyWith(showWatermark: !remove);
    });
  }

  void _onPhotoBackdropChanged(CardThemeConfig next) {
    final previous = _theme.customBackgroundImagePath;
    final removed = previous != null && next.customBackgroundImagePath == null;
    setState(() => _theme = next);
    if (removed) {
      unawaited(widget.photoBackdropStore.deleteIfManaged(previous));
    }
  }

  Future<void> _pickPhotoBackdrop() async {
    if (!ref.read(canAccessProFeatureProvider)) {
      await _promptUpgrade(
        highlight: 'Custom photo backdrops with blur and contrast scrim',
      );
      return;
    }
    final previous = _theme.customBackgroundImagePath;
    final path = await widget.photoBackdropStore.pickFromGallery();
    if (!mounted || path == null) return;
    setState(() {
      _theme = _theme.copyWith(customBackgroundImagePath: path);
    });
    try {
      await precacheImage(FileImage(File(path)), context);
    } catch (_) {
      // Preview still renders via Image.file errorBuilder.
    }
    if (previous != null && previous != path) {
      unawaited(widget.photoBackdropStore.deleteIfManaged(previous));
    }
  }

  Future<void> _promptUpgrade({String? highlight}) async {
    await PaywallBottomSheet.show(context, highlightBenefit: highlight);
  }

  void _onFontPairingSelected(FontPairing pairing) {
    if (pairing.isPro && !ref.read(canAccessProFeatureProvider)) {
      unawaited(_promptUpgrade(highlight: '${pairing.name} font pairing'));
      return;
    }
    setState(() {
      _fontPairingId = pairing.id;
      _activeKitId = null;
    });
  }

  void _applyBrandKit(BrandKit kit) {
    final pairing = FontPairings.byId(kit.fontPairingId);
    final fontLocked =
        pairing != null &&
        pairing.isPro &&
        !ref.read(canAccessProFeatureProvider);
    setState(() {
      _activeKitId = kit.id;
      _aspect = kit.aspectRatio;
      _theme = BrandPalette.apply(_theme, kit);
      _logoPath = kit.logoPath;
      if (!fontLocked && pairing != null) {
        _fontPairingId = pairing.id;
      }
    });
    unawaited(_precacheLogo(kit.logoPath));
    if (fontLocked) {
      unawaited(_promptUpgrade(highlight: '${pairing.name} font pairing'));
    }
  }

  Future<void> _saveBrandKit() async {
    if (_isBusy) return;
    final storage = ref.read(brandKitStorageProvider);
    final probe = BrandKit(
      id: generateBrandKitId(),
      name: 'Personal Brand',
      primaryColor: HexColor.format(_theme.backgroundColor),
      secondaryColor: HexColor.format(_theme.textColor),
      fontPairingId: _fontPairingId ?? FontPairings.modernTech.id,
      logoPath: _logoPath,
      aspectRatio: _aspect,
    );
    if (!storage.canSave(
      probe,
      isProPurchased: ref.read(isProPurchasedProvider),
    )) {
      await _promptUpgrade(highlight: 'Free accounts can save 1 brand kit');
      return;
    }
    if (!mounted) return;
    final draft = await BrandKitSaveSheet.show(context);
    if (draft == null || !mounted) return;
    final kit = probe.copyWith(
      name: draft.name,
      logoPath: draft.logoPath ?? probe.logoPath,
    );
    final saved = await ref
        .read(brandKitsProvider.notifier)
        .saveKit(kit, isProPurchased: ref.read(isProPurchasedProvider));
    if (!mounted) return;
    if (!saved) {
      await _promptUpgrade(highlight: 'Free accounts can save 1 brand kit');
      return;
    }
    setState(() {
      _activeKitId = kit.id;
      _logoPath = kit.logoPath;
    });
    unawaited(_precacheLogo(kit.logoPath));
  }

  Future<void> _deleteBrandKit(BrandKit kit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete brand kit?'),
          content: Text('“${kit.name}” will be removed from this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('brand-kit-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await ref.read(brandKitsProvider.notifier).deleteKit(kit.id);
    if (!mounted) return;
    if (_activeKitId == kit.id) {
      setState(() => _activeKitId = null);
    }
  }

  Future<void> _precacheLogo(String? path) async {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    final file = File(trimmed);
    if (!await file.exists() || !mounted) return;
    try {
      await precacheImage(FileImage(file), context);
    } catch (_) {
      // The canvas errorBuilder keeps the layout if the file cannot decode.
    }
  }

  Future<void> _openProfileSwitcher() async {
    final selected = await BrandProfileSheet.show(context);
    if (selected == null || !mounted) return;
    await ref.read(cardSettingsProvider.notifier).selectProfile(selected.id);
    if (!mounted) return;
    _applyProfileTheme(selected);
  }

  void _applyProfileTheme(AuthorProfile profile) {
    final settings = ref.read(cardSettingsProvider);
    final resolved = CardPresets.resolve(
      profile.defaultThemeId,
      customBackground: Color(settings.customBackgroundColor),
      customText: Color(settings.customTextColor),
    );
    if (resolved.isPremium && !ref.read(canAccessProFeatureProvider)) return;
    setState(() {
      _theme = resolved.withExporterChrome(_theme);
    });
  }

  GlobalKey _previewKeyFor(int index) =>
      _previewKeys.putIfAbsent(index, GlobalKey.new);

  SlideRole _roleAt(int index) {
    final total = _deck.totalSlides;
    final safe = total <= 1 ? 0 : index.clamp(0, total - 1);
    return SlideRoles.resolve(
      override: _roleOverrides[safe],
      index: safe,
      totalSlides: total,
    );
  }

  ({String? path, String initials, Color color}) get _creatorAvatar {
    final settings = ref.read(cardSettingsProvider);
    final profile = settings.activeProfile;
    final preset =
        (profile?.avatarPreset ?? settings.avatarPreset) %
        brandAvatarColors.length;
    return (
      path: profile?.avatarPath ?? settings.avatarPath,
      initials: profile?.initials ?? settings.initials,
      color: brandAvatarColors[preset],
    );
  }

  Widget _buildHero(bool isPro) {
    final deck = _deck;
    final avatar = _creatorAvatar;
    final safeIndex = deck.totalSlides <= 1
        ? 0
        : _slideIndex.clamp(0, deck.totalSlides - 1);

    final Widget preview;
    if (!deck.isCarousel) {
      preview = _ScaledPreview(
        canvasKey: _canvasKey,
        text: deck.slideAt(0),
        aspectRatio: _aspect,
        theme: _theme,
        author: _authorName,
        authorHandle: _authorHandle,
        isProPurchased: isPro,
        slideRole: _roleAt(0),
        avatarPath: avatar.path,
        avatarInitials: avatar.initials,
        avatarColor: avatar.color,
        fontPairingId: _fontPairingId,
        logoPath: _logoPath,
        showQrCode: _showQrCode,
        qrDestination: _qrController.text,
        currentSlideIndex: 0,
        totalSlides: deck.totalSlides,
        onInspect: _isBusy
            ? null
            : () => unawaited(_openInspect(deck.slideAt(0))),
      );
    } else {
      preview = PageView.builder(
        key: const Key('carousel-page-view'),
        controller: _pageController,
        physics: _isBusy
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: deck.totalSlides,
        onPageChanged: (index) => setState(() => _slideIndex = index),
        itemBuilder: (context, index) {
          return _ScaledPreview(
            canvasKey: _previewKeyFor(index),
            text: deck.slideAt(index),
            aspectRatio: _aspect,
            theme: _theme,
            author: _authorName,
            authorHandle: _authorHandle,
            isProPurchased: isPro,
            slideRole: _roleAt(index),
            avatarPath: avatar.path,
            avatarInitials: avatar.initials,
            avatarColor: avatar.color,
            fontPairingId: _fontPairingId,
            logoPath: _logoPath,
            showQrCode: _showQrCode,
            qrDestination: _qrController.text,
            currentSlideIndex: index,
            totalSlides: deck.totalSlides,
            onInspect: _isBusy
                ? null
                : () => unawaited(_openInspect(deck.slideAt(index))),
          );
        },
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          if (deck.isCarousel)
            _CarouselBanner(
              label: deck.slideOfLabel(safeIndex),
              onPrevious: _isBusy || safeIndex <= 0
                  ? null
                  : () => unawaited(_goToPage(safeIndex - 1)),
              onNext: _isBusy || safeIndex >= deck.totalSlides - 1
                  ? null
                  : () => unawaited(_goToPage(safeIndex + 1)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: preview,
            ),
          ),
        ],
      ),
    );
  }

  void _setRole(SlideRole role) {
    setState(() => _roleOverrides[_slideIndex] = role);
  }

  void _reorderSlides(int oldIndex, int newIndex) {
    final length = _deck.totalSlides;
    final next = CarouselMarkdown.reorder(_markdown, oldIndex, newIndex);
    final focus = SlideRoles.reorderDestination(oldIndex, newIndex, length);
    final overrides = SlideRoles.remapAfterReorder(
      _roleOverrides,
      oldIndex,
      newIndex,
      length,
    );
    _commitMarkdown(next, focusIndex: focus, overrides: overrides);
  }

  void _duplicateSlide(int index) {
    final length = _deck.totalSlides;
    final next = CarouselMarkdown.duplicate(_markdown, index);
    final overrides = SlideRoles.remapAfterDuplicate(
      _roleOverrides,
      index,
      length,
    );
    _commitMarkdown(next, focusIndex: index + 1, overrides: overrides);
  }

  void _deleteSlide(int index) {
    final length = _deck.totalSlides;
    if (length <= 1) return;
    final next = CarouselMarkdown.delete(_markdown, index);
    final overrides = SlideRoles.remapAfterDelete(
      _roleOverrides,
      index,
      length,
    );
    final focus = index >= length - 1 ? index - 1 : index;
    _commitMarkdown(next, focusIndex: focus, overrides: overrides);
  }

  void _addSlide() {
    final next = CarouselMarkdown.addSlide(_markdown);
    final focus = CarouselDeck.fromMarkdown(next).totalSlides - 1;
    _commitMarkdown(next, focusIndex: focus);
  }

  void _commitMarkdown(
    String markdown, {
    required int focusIndex,
    Map<int, SlideRole>? overrides,
  }) {
    final deck = CarouselDeck.fromMarkdown(markdown);
    final last = deck.totalSlides - 1;
    final focus = last < 0 ? 0 : focusIndex.clamp(0, last);
    if (_pageController.hasClients) {
      final currentCount = _deck.totalSlides;
      if (focus < currentCount && _pageController.page?.round() != focus) {
        _pageController.jumpToPage(focus);
      }
    }
    setState(() {
      _markdown = markdown;
      _slideIndex = focus;
      if (overrides != null) {
        _roleOverrides
          ..clear()
          ..addAll(overrides);
      }
    });
    _syncActiveDraft(markdown);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final page = _pageController.page?.round();
      if (page != focus) _pageController.jumpToPage(focus);
    });
  }

  void _syncActiveDraft(String markdown) {
    ref.read(scratchpadProvider.notifier).updateContent(markdown);
  }

  Future<void> _openInspect(String text) {
    final avatar = _creatorAvatar;
    final deck = _deck;
    return CardInspectModal.show(
      context: context,
      text: text,
      aspectRatio: _aspect,
      theme: _theme,
      isProPurchased: ref.read(canAccessProFeatureProvider),
      author: _authorName,
      authorHandle: _authorHandle,
      currentSlideIndex: _slideIndex,
      totalSlides: deck.totalSlides,
      slideRole: _roleAt(_slideIndex),
      avatarPath: avatar.path,
      avatarInitials: avatar.initials,
      avatarColor: avatar.color,
      fontPairingId: _fontPairingId,
      logoPath: _logoPath,
      showQrCode: _showQrCode,
      qrDestination: _qrController.text,
    );
  }

  GlobalKey get _activeCanvasKey {
    if (_deck.isCarousel) return _previewKeyFor(_slideIndex);
    return _canvasKey;
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

  Future<List<Uint8List>> _rasterizeDeck(
    CarouselDeck deck, {
    CardAspectRatio? aspect,
  }) {
    return widget.batchExporter.renderDeck(
      deck,
      _theme,
      aspect ?? _aspect,
      ref.read(canAccessProFeatureProvider),
      context: context,
      author: _authorName,
      authorHandle: _authorHandle,
      slideRoles: [for (var i = 0; i < deck.totalSlides; i++) _roleAt(i)],
      avatarPath: _creatorAvatar.path,
      avatarInitials: _creatorAvatar.initials,
      avatarColor: _creatorAvatar.color,
      fontPairingId: _fontPairingId,
      logoPath: _logoPath,
      showQrCode: _showQrCode,
      qrDestination: _qrController.text,
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
    _beginExport(_ExportAction.share, deck);
    try {
      if (deck.isCarousel) {
        final images = await _rasterizeDeck(deck);
        if (!mounted) return;
        if (images.isEmpty) {
          _showToast('Could not capture card');
          return;
        }
        setState(() => _lastPngBytes = images.last);
        await widget.shareExportService.shareCarouselPdf(
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
        await widget.shareExportService.shareSingleCard(
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
      _clearBusy();
    }
  }

  Future<void> _saveToPhotos() async {
    if (_isBusy) return;
    final deck = _deck;
    _beginExport(_ExportAction.save, deck);
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
      _clearBusy();
    }
  }

  Future<void> _copyCard() async {
    if (_isBusy) return;
    setState(() {
      _busy = _ExportAction.copy;
      _exportCurrent = null;
      _exportTotal = null;
    });
    try {
      final bytes = await widget.rasterizer.capturePng(_activeCanvasKey);
      if (!mounted) return;
      if (bytes == null) {
        _showToast('Could not capture card');
        return;
      }
      setState(() => _lastPngBytes = bytes);
      final copied = await widget.exportService.copyImageToClipboard(bytes);
      if (!mounted) return;
      if (copied) {
        unawaited(HapticFeedback.mediumImpact());
        _showToast('Card copied to clipboard! Ready to paste.');
      } else {
        _showToast('Could not copy card');
      }
    } catch (_) {
      if (!mounted) return;
      _showToast('Could not copy card');
    } finally {
      _clearBusy();
    }
  }

  Future<void> _exportLinkedInPdf(BuildContext buttonContext) async {
    if (_isBusy) return;
    if (!ref.read(canAccessProFeatureProvider)) {
      await _promptUpgrade(
        highlight: 'Export swipeable LinkedIn PDF carousels',
      );
      return;
    }
    final origin = _shareOrigin(buttonContext);
    final deck = _deck;
    if (!deck.isCarousel) return;
    _beginExport(_ExportAction.pdf, deck);
    try {
      final images = await _rasterizeDeck(deck, aspect: CardAspectRatio.square);
      if (!mounted) return;
      if (images.isEmpty) {
        _showToast('Could not capture card');
        return;
      }
      setState(() => _lastPngBytes = images.last);
      await widget.exportService.shareLinkedInPdf(
        images,
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
    } catch (_) {
      if (!mounted) return;
      _showToast('Could not export LinkedIn PDF');
    } finally {
      _clearBusy();
    }
  }

  void _beginExport(_ExportAction action, CarouselDeck deck) {
    setState(() {
      _busy = action;
      if (deck.isCarousel) {
        _exportCurrent = 1;
        _exportTotal = deck.totalSlides;
      } else {
        _exportCurrent = null;
        _exportTotal = null;
      }
    });
  }

  void _clearBusy() {
    if (!mounted) return;
    setState(() {
      _busy = null;
      _exportCurrent = null;
      _exportTotal = null;
    });
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

enum _ExportAction { share, save, copy, pdf }

class _ExportActionBar extends StatelessWidget {
  const _ExportActionBar({
    required this.busy,
    required this.isCarousel,
    required this.slideCount,
    required this.isProPurchased,
    required this.onShare,
    required this.onSave,
    required this.onCopy,
    required this.onExportPdf,
  });

  final _ExportAction? busy;
  final bool isCarousel;
  final int slideCount;
  final bool isProPurchased;
  final ValueChanged<BuildContext> onShare;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final ValueChanged<BuildContext> onExportPdf;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: isCarousel ? 11.5 : 13,
    );
    final isBusy = busy != null;
    final shareLabel = busy == _ExportAction.share
        ? 'Sharing…'
        : (isCarousel ? 'Share PDF' : 'Share');
    final saveLabel = busy == _ExportAction.save
        ? (isCarousel ? 'Exporting…' : 'Saving…')
        : (isCarousel ? 'Save All ($slideCount Slides)' : 'Save Image');
    final pdfLabel = busy == _ExportAction.pdf
        ? 'Exporting PDF…'
        : 'Export LinkedIn PDF';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCarousel) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Builder(
              builder: (buttonContext) {
                return FilledButton.icon(
                  key: const Key('export-linkedin-pdf'),
                  onPressed: isBusy ? null : () => onExportPdf(buttonContext),
                  icon: busy == _ExportAction.pdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isProPurchased
                              ? Icons.picture_as_pdf_outlined
                              : Icons.lock_outline,
                          size: 18,
                        ),
                  label: Text(
                    pdfLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
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
                          : const Icon(Icons.share, size: 18),
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
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              Flexible(
                child: OutlinedButton.icon(
                  key: const Key('copy-card-png'),
                  onPressed: isBusy ? null : onCopy,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: busy == _ExportAction.copy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.content_copy, size: 18),
                  label: Text(
                    'Copy Card',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    this.authorHandle,
    this.currentSlideIndex,
    this.totalSlides,
    this.slideRole,
    this.avatarPath,
    this.avatarInitials = '',
    this.avatarColor,
    this.fontPairingId,
    this.logoPath,
    this.showQrCode = false,
    this.qrDestination,
    this.onInspect,
  });

  final GlobalKey canvasKey;
  final String text;
  final CardAspectRatio aspectRatio;
  final CardThemeConfig theme;
  final String? author;
  final String? authorHandle;
  final bool isProPurchased;
  final int? currentSlideIndex;
  final int? totalSlides;
  final SlideRole? slideRole;
  final String? avatarPath;
  final String avatarInitials;
  final Color? avatarColor;
  final String? fontPairingId;
  final String? logoPath;
  final bool showQrCode;
  final String? qrDestination;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    final ratio = aspectRatio.width / aspectRatio.height;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.35),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: ratio,
            child: GestureDetector(
              key: const Key('card-preview-tap'),
              behavior: HitTestBehavior.opaque,
              onTap: onInspect,
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
                    authorHandle: authorHandle,
                    isProPurchased: isProPurchased,
                    currentSlideIndex: currentSlideIndex,
                    totalSlides: totalSlides,
                    slideRole: slideRole,
                    avatarPath: avatarPath,
                    avatarInitials: avatarInitials,
                    avatarColor: avatarColor,
                    fontPairingId: fontPairingId,
                    logoPath: logoPath,
                    showQrCode: showQrCode,
                    qrDestination: qrDestination,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AspectSwitch extends StatelessWidget {
  const _AspectSwitch({required this.selected, required this.onChanged});

  final CardAspectRatio selected;
  final ValueChanged<CardAspectRatio>? onChanged;

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
      onSelectionChanged: onChanged == null
          ? null
          : (next) {
              if (next.isEmpty) return;
              onChanged!(next.single);
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

class _ProfileSwitcherPill extends StatelessWidget {
  const _ProfileSwitcherPill({
    required this.settings,
    required this.enabled,
    required this.onTap,
  });

  final CardSettings settings;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = settings.activeProfile;
    final name =
        profile?.displayName ??
        (settings.authorName.trim().isNotEmpty
            ? settings.authorName.trim()
            : 'My Brand');
    final initials = profile?.initials ?? settings.initials;
    final avatarColor =
        brandAvatarColors[(profile?.avatarPreset ?? settings.avatarPreset) %
            brandAvatarColors.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          shape: StadiumBorder(
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            key: const Key('profile-switcher-pill'),
            onTap: enabled ? onTap : null,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: avatarColor,
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
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
    required this.isProPurchased,
    required this.canAccessPro,
    required this.removeWatermark,
    required this.onChanged,
  });

  final bool isProPurchased;
  final bool canAccessPro;
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
        isProPurchased ? Icons.water_drop_outlined : Icons.lock_outline,
        key: isProPurchased
            ? const Key('watermark-unlocked')
            : const Key('watermark-lock'),
        size: 20,
        color: colors.onSurface.withValues(alpha: 0.6),
      ),
      value: canAccessPro && removeWatermark,
      onChanged: onChanged,
    );
  }
}

class _TemplateCarousel extends StatelessWidget {
  const _TemplateCarousel({
    required this.selected,
    required this.isProPurchased,
    required this.onSelected,
  });

  final CardThemeConfig selected;
  final bool isProPurchased;
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
          final swatch = isSelected ? selected : preset;
          return _TemplateChip(
            preset: swatch,
            selected: isSelected,
            locked: preset.isPremium && !isProPurchased,
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
  final ValueChanged<int>? onSelected;

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
                onTap: onSelected == null ? null : () => onSelected!(i),
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

class _ExportProgressOverlay extends StatelessWidget {
  const _ExportProgressOverlay({this.current, this.total});

  final int? current;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final isCarousel = current != null && total != null;
    final status = isCarousel
        ? 'Preparing slide $current of $total...'
        : 'Rendering 1080px card...';

    return Positioned.fill(
      key: const Key('export-progress-overlay'),
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.22),
              child: Center(
                child: DecoratedBox(
                  key: isCarousel
                      ? const Key('carousel-export-progress')
                      : null,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          status,
                          key: const Key('export-progress-status'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
