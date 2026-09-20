import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

/// Social-export canvas size. Layout is always these logical pixels so
/// rasterization is independent of device screen size and DPI.
enum CardAspectRatio {
  square(1080, 1080, '1:1 Square'),
  story(1080, 1920, '9:16 Story');

  const CardAspectRatio(this.width, this.height, this.label);

  /// Target canvas width in logical pixels (always 1080).
  final double width;

  /// Target canvas height in logical pixels.
  final double height;

  /// Segmented-control label.
  final String label;

  Size get size => Size(width, height);
}

/// Sentinel so [CardThemeConfig.copyWith] can clear [customBackgroundImagePath].
const Object _unsetCustomBackground = Object();

/// Visual identity of a card template. Pure presentation config — no state.
class CardThemeConfig {
  const CardThemeConfig({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.fontFamily,
    this.backgroundGradient,
    this.overlayGradients = const [],
    this.borderWidth,
    this.borderColor,
    this.showWatermark = true,
    this.isPremium = false,
    this.variant = CardTemplateVariant.plain,
    this.chromeTitle = 'clean-canvas.md',
    this.customBackgroundImagePath,
    this.blurSigma = defaultBlurSigma,
    this.overlayOpacity = defaultOverlayOpacity,
    this.isDarkOverlay = true,
  });

  static const fontInter = 'Inter';
  static const fontJetBrainsMono = 'JetBrains Mono';

  static const double minBlurSigma = 0;
  static const double maxBlurSigma = 30;
  static const double defaultBlurSigma = 12;

  static const double minOverlayOpacity = 0.2;
  static const double maxOverlayOpacity = 0.85;
  static const double defaultOverlayOpacity = 0.5;

  final String id;
  final String name;
  final Color backgroundColor;
  final Gradient? backgroundGradient;

  /// Extra blooms painted over [backgroundGradient] (Aurora indigo/violet).
  final List<Gradient> overlayGradients;

  final Color textColor;
  final Color accentColor;
  final String fontFamily;

  /// When null, plain templates use a 3px hairline in [accentColor].
  /// Set to `0` to omit a border. Neo-Brutalist uses `4`.
  final double? borderWidth;

  /// Solid border color. Null falls back to a translucent [accentColor].
  final Color? borderColor;

  /// Free-tier default is `true`. Pro may strip this; [CardCanvas] still
  /// forces a watermark when [isProPurchased] is false.
  final bool showWatermark;

  /// Midnight, Terminal, Aurora, Editorial, Neo-Brutal, and Custom require Pro.
  final bool isPremium;

  final CardTemplateVariant variant;

  /// Filename shown in the Dev Terminal title bar.
  final String chromeTitle;

  /// Absolute on-device path of a user-picked photo backdrop.
  /// Never uploaded; lives in temp or application-support storage.
  final String? customBackgroundImagePath;

  /// Gaussian blur sigma applied to [customBackgroundImagePath] (`0`–`30`).
  final double blurSigma;

  /// Contrast scrim opacity over the photo (`0.2`–`0.85`).
  final double overlayOpacity;

  /// Dark scrim (white type) vs light scrim (dark type).
  final bool isDarkOverlay;

  bool get isMonospace => fontFamily == fontJetBrainsMono;

  bool get hasCustomBackground {
    final path = customBackgroundImagePath;
    return path != null && path.isNotEmpty;
  }

  /// Blur clamped to the interactive slider range.
  double get resolvedBlurSigma => blurSigma.clamp(minBlurSigma, maxBlurSigma);

  /// Scrim opacity clamped so type stays legible.
  double get resolvedOverlayOpacity =>
      overlayOpacity.clamp(minOverlayOpacity, maxOverlayOpacity);

  /// Foreground type when a photo backdrop is active.
  Color get photoAwareTextColor {
    if (!hasCustomBackground) return textColor;
    return isDarkOverlay ? const Color(0xFFF8FAFC) : const Color(0xFF1F2937);
  }

  /// Always-on contrast tint painted over the blurred photo.
  Color get photoScrimColor {
    final base = isDarkOverlay ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return base.withValues(alpha: resolvedOverlayOpacity);
  }

  bool get isCustom => id == CardPresets.customId;

  bool get isDark {
    if (variant == CardTemplateVariant.terminal) return true;
    return backgroundColor.computeLuminance() < 0.35;
  }

  /// Resolved card outline used by [CardCanvas].
  Border? get resolvedBorder {
    if (variant == CardTemplateVariant.terminal) return null;
    final width = borderWidth ?? 3;
    if (width <= 0) return null;
    final color = borderColor ?? accentColor.withValues(alpha: 0.45);
    return Border.all(color: color, width: width);
  }

  /// Hard render gate: free users always keep the watermark even if a caller
  /// passes `showWatermark: false`. Custom photo backdrops are also stripped.
  /// [kDemoModeBypassPaywall] is the single demo switch that lets recordings
  /// unlock Pro chrome without a purchase.
  CardThemeConfig enforcedFor({required bool isProPurchased}) {
    if (canAccessProFeature(isProPurchased: isProPurchased)) return this;
    return copyWith(
      showWatermark: true,
      customBackgroundImagePath: null,
    );
  }

  /// Copies watermark + photo-backdrop chrome from [other] onto this preset.
  CardThemeConfig withExporterChrome(CardThemeConfig other) {
    return copyWith(
      showWatermark: other.showWatermark,
      customBackgroundImagePath: other.customBackgroundImagePath,
      blurSigma: other.blurSigma,
      overlayOpacity: other.overlayOpacity,
      isDarkOverlay: other.isDarkOverlay,
    );
  }

  CardThemeConfig copyWith({
    String? id,
    String? name,
    Color? backgroundColor,
    Gradient? backgroundGradient,
    List<Gradient>? overlayGradients,
    Color? textColor,
    Color? accentColor,
    String? fontFamily,
    double? borderWidth,
    Color? borderColor,
    bool? showWatermark,
    bool? isPremium,
    CardTemplateVariant? variant,
    String? chromeTitle,
    Object? customBackgroundImagePath = _unsetCustomBackground,
    double? blurSigma,
    double? overlayOpacity,
    bool? isDarkOverlay,
  }) {
    return CardThemeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      overlayGradients: overlayGradients ?? this.overlayGradients,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      showWatermark: showWatermark ?? this.showWatermark,
      isPremium: isPremium ?? this.isPremium,
      variant: variant ?? this.variant,
      chromeTitle: chromeTitle ?? this.chromeTitle,
      customBackgroundImagePath: identical(
            customBackgroundImagePath,
            _unsetCustomBackground,
          )
          ? this.customBackgroundImagePath
          : customBackgroundImagePath as String?,
      blurSigma: blurSigma ?? this.blurSigma,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      isDarkOverlay: isDarkOverlay ?? this.isDarkOverlay,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CardThemeConfig &&
        other.id == id &&
        other.name == name &&
        other.backgroundColor == backgroundColor &&
        other.textColor == textColor &&
        other.accentColor == accentColor &&
        other.fontFamily == fontFamily &&
        other.borderWidth == borderWidth &&
        other.borderColor == borderColor &&
        other.showWatermark == showWatermark &&
        other.isPremium == isPremium &&
        other.variant == variant &&
        other.chromeTitle == chromeTitle &&
        other.customBackgroundImagePath == customBackgroundImagePath &&
        other.blurSigma == blurSigma &&
        other.overlayOpacity == overlayOpacity &&
        other.isDarkOverlay == isDarkOverlay;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        backgroundColor,
        textColor,
        accentColor,
        fontFamily,
        borderWidth,
        borderColor,
        showWatermark,
        isPremium,
        variant,
        chromeTitle,
        customBackgroundImagePath,
        blurSigma,
        overlayOpacity,
        isDarkOverlay,
      );
}

enum CardTemplateVariant { plain, terminal }

/// Built-in visual presets. Advanced palettes and Custom Brand are Pro.
abstract final class CardPresets {
  static const String customId = 'custom';

  /// Minimal Clean — light paper, charcoal type, hairline accent border.
  static const minimalClean = CardThemeConfig(
    id: 'minimal',
    name: 'Minimal',
    backgroundColor: Color(0xFFF8F9FA),
    textColor: Color(0xFF1F2937),
    accentColor: Color(0xFF94A3B8),
    fontFamily: CardThemeConfig.fontInter,
  );

  /// Midnight Dark — deep slate with high-contrast off-white type.
  static const midnightDark = CardThemeConfig(
    id: 'midnight',
    name: 'Midnight',
    backgroundColor: Color(0xFF0F172A),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    ),
    textColor: Color(0xFFF8FAFC),
    accentColor: Color(0xFF38BDF8),
    fontFamily: CardThemeConfig.fontInter,
    isPremium: true,
  );

  /// Dev Terminal — VS Code-like chrome with traffic-light controls.
  static const devTerminal = CardThemeConfig(
    id: 'terminal',
    name: 'Terminal',
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFD4D4D4),
    accentColor: Color(0xFF569CD6),
    fontFamily: CardThemeConfig.fontJetBrainsMono,
    variant: CardTemplateVariant.terminal,
    isPremium: true,
  );

  /// Modern Aurora — deep slate with indigo / violet glow blooms.
  static const modernAurora = CardThemeConfig(
    id: 'aurora',
    name: 'Aurora',
    backgroundColor: Color(0xFF0B0F19),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B0F19), Color(0xFF17122B)],
    ),
    overlayGradients: [
      RadialGradient(
        center: Alignment(-0.55, -0.6),
        radius: 1.15,
        colors: [Color(0xB34F46E5), Color(0x000B0F19)],
      ),
      RadialGradient(
        center: Alignment(0.7, 0.65),
        radius: 1.2,
        colors: [Color(0xA69333EA), Color(0x000B0F19)],
      ),
    ],
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFF818CF8),
    fontFamily: CardThemeConfig.fontInter,
    isPremium: true,
  );

  /// Editorial Warm — antique cream paper with charcoal type.
  static const editorialWarm = CardThemeConfig(
    id: 'editorial',
    name: 'Editorial',
    backgroundColor: Color(0xFFF9F6EE),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF9F6EE), Color(0xFFF3EBDA)],
    ),
    textColor: Color(0xFF1C1917),
    accentColor: Color(0xFFC2410C),
    fontFamily: CardThemeConfig.fontInter,
    isPremium: true,
  );

  /// Neo-Brutalist — canary field, pitch-black type, 4px solid border.
  static const neoBrutalist = CardThemeConfig(
    id: 'neo_brutal',
    name: 'Neo-Brutal',
    backgroundColor: Color(0xFFFEF08A),
    textColor: Color(0xFF000000),
    accentColor: Color(0xFFA7F3D0),
    fontFamily: CardThemeConfig.fontInter,
    borderWidth: 4,
    borderColor: Color(0xFF000000),
    isPremium: true,
  );

  /// Custom Brand placeholder. Live colors come from [customBrand].
  static const customBrand = CardThemeConfig(
    id: customId,
    name: 'Custom',
    backgroundColor: Color(0xFF0F172A),
    textColor: Color(0xFFF8FAFC),
    accentColor: Color(0xFFF59E0B),
    fontFamily: CardThemeConfig.fontInter,
    isPremium: true,
  );

  static const List<CardThemeConfig> all = [
    minimalClean,
    midnightDark,
    devTerminal,
    modernAurora,
    editorialWarm,
    neoBrutalist,
    customBrand,
  ];

  static CardThemeConfig byId(String id) {
    return all.firstWhere(
      (preset) => preset.id == id,
      orElse: () => minimalClean,
    );
  }

  /// Custom Brand with caller-picked background and type colors.
  static CardThemeConfig custom({
    Color backgroundColor = const Color(0xFF0F172A),
    Color textColor = const Color(0xFFF8FAFC),
  }) {
    return customBrand.copyWith(
      backgroundColor: backgroundColor,
      textColor: textColor,
      accentColor: _accentFor(backgroundColor, textColor),
    );
  }

  static CardThemeConfig resolve(
    String themeId, {
    Color? customBackground,
    Color? customText,
  }) {
    if (themeId == customId) {
      return custom(
        backgroundColor: customBackground ?? customBrand.backgroundColor,
        textColor: customText ?? customBrand.textColor,
      );
    }
    return byId(themeId);
  }

  static Color _accentFor(Color background, Color text) {
    final warm = background.computeLuminance() < 0.35
        ? const Color(0xFFF59E0B)
        : const Color(0xFFC2410C);
    return Color.lerp(warm, text, 0.15) ?? warm;
  }
}

/// Padding and type scale used by [CardCanvas] at the fixed 1080px width.
///
/// Sizes are canvas pixels (not mobile/desktop points). Body copy on a
/// 1080px-wide card should sit in the 36–42px range so FittedBox previews
/// stay readable without zooming.
abstract final class CardLayout {
  /// Horizontal inset on the 1080px canvas.
  static const double padding = 84;

  /// Vertical header/footer inset on the 1080px canvas.
  static const double verticalPadding = 64;
  static const double headerHeight = 104;
  static const double footerHeight = 72;
  static const String watermarkLabel = 'Made with PenningPal';

  static const double authorNameSize = 32;
  static const double authorHandleSize = 26;
  static const double watermarkSize = 24;

  static const double punchyScale = 1.35;
  static const double standardScale = 1.1;
  static const double longFormScale = 0.95;
  static const double denseScale = 0.82;

  static const int punchyMaxChars = 140;
  static const int standardMaxChars = 350;
  static const int longFormMaxChars = 700;

  static double contentWidth(CardAspectRatio ratio) =>
      ratio.width - (padding * 2);

  /// Dynamic type multiplier from slide character length.
  ///
  /// Punchy one-liners scale up so they fill the canvas; long-form copy
  /// scales down but never below [denseScale] so type stays legible.
  static double fontScaleFor(String text) {
    final length = text.trim().length;
    if (length < punchyMaxChars) return punchyScale;
    if (length < standardMaxChars) return standardScale;
    if (length <= longFormMaxChars) return longFormScale;
    return denseScale;
  }

  static double fontSizeFor(String text, CardAspectRatio ratio) {
    final base = ratio == CardAspectRatio.square ? 38.0 : 42.0;
    return base * fontScaleFor(text);
  }
}

/// `#RRGGBB` / `#AARRGGBB` helpers for the Custom Brand picker.
abstract final class HexColor {
  static Color? tryParse(String input) {
    var hex = input.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static Color parse(String input, {Color fallback = const Color(0xFF000000)}) {
    return tryParse(input) ?? fallback;
  }

  static String format(Color color) {
    final argb = color.toARGB32();
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }
}

/// Curated brand swatches shown in the Custom Brand picker.
abstract final class BrandColorSwatches {
  static const List<Color> all = [
    Color(0xFF0B0F19),
    Color(0xFF0F172A),
    Color(0xFF1E1E1E),
    Color(0xFFF8F9FA),
    Color(0xFFF9F6EE),
    Color(0xFFFEF08A),
    Color(0xFFA7F3D0),
    Color(0xFF4F46E5),
    Color(0xFF9333EA),
    Color(0xFFC2410C),
    Color(0xFF1C1917),
    Color(0xFFFFFFFF),
  ];
}
