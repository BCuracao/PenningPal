import 'package:flutter/material.dart';

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
    this.showWatermark = true,
    this.isPremium = false,
    this.variant = CardTemplateVariant.plain,
    this.chromeTitle = 'clean-canvas.md',
  });

  static const fontInter = 'Inter';
  static const fontJetBrainsMono = 'JetBrains Mono';

  final String id;
  final String name;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final Color textColor;
  final Color accentColor;
  final String fontFamily;

  /// Free-tier default is `true`. Pro may strip this; [CardCanvas] still
  /// forces a watermark when [isProPurchased] is false.
  final bool showWatermark;

  /// Midnight, Terminal, and custom palettes require Pro.
  final bool isPremium;

  final CardTemplateVariant variant;

  /// Filename shown in the Dev Terminal title bar.
  final String chromeTitle;

  bool get isMonospace => fontFamily == fontJetBrainsMono;

  /// Hard render gate: free users always keep the watermark even if a caller
  /// passes `showWatermark: false`.
  CardThemeConfig enforcedFor({required bool isProPurchased}) {
    if (isProPurchased) return this;
    return copyWith(showWatermark: true);
  }

  CardThemeConfig copyWith({
    String? id,
    String? name,
    Color? backgroundColor,
    Gradient? backgroundGradient,
    Color? textColor,
    Color? accentColor,
    String? fontFamily,
    bool? showWatermark,
    bool? isPremium,
    CardTemplateVariant? variant,
    String? chromeTitle,
  }) {
    return CardThemeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
      showWatermark: showWatermark ?? this.showWatermark,
      isPremium: isPremium ?? this.isPremium,
      variant: variant ?? this.variant,
      chromeTitle: chromeTitle ?? this.chromeTitle,
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
        other.showWatermark == showWatermark &&
        other.isPremium == isPremium &&
        other.variant == variant &&
        other.chromeTitle == chromeTitle;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        backgroundColor,
        textColor,
        accentColor,
        fontFamily,
        showWatermark,
        isPremium,
        variant,
        chromeTitle,
      );
}

enum CardTemplateVariant { plain, terminal }

/// Built-in visual presets. Midnight, Terminal, and custom palettes are Pro.
abstract final class CardPresets {
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

  static const List<CardThemeConfig> all = [
    minimalClean,
    midnightDark,
    devTerminal,
  ];

  static CardThemeConfig byId(String id) {
    return all.firstWhere(
      (preset) => preset.id == id,
      orElse: () => minimalClean,
    );
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
