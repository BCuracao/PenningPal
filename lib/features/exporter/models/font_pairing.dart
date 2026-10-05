import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';

/// Narrow view of a `GoogleFonts.*` builder.
///
/// Each curated preset stores the real Google Fonts method (or a thin wrapper
/// around one) so headlines and body copy can be painted without a network
/// call of our own. `google_fonts` still resolves the font files.
typedef GoogleFontMethod = TextStyle Function({
  TextStyle? textStyle,
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
});

/// A headline + body combination offered in the card exporter.
class FontPairing {
  const FontPairing({
    required this.id,
    required this.name,
    required this.headerFont,
    required this.bodyFont,
    required this.headerFamily,
    required this.bodyFamily,
    required this.isPro,
  });

  final String id;
  final String name;

  /// Google Fonts builder for headings, author names, and cover eyebrows.
  final GoogleFontMethod headerFont;

  /// Google Fonts builder for body copy, handles, and the watermark.
  final GoogleFontMethod bodyFont;

  /// Family name used when painting headings.
  final String headerFamily;

  /// Family name used when painting body copy.
  final String bodyFamily;

  /// Editorial, High Impact, and Minimalist require Pro.
  final bool isPro;

  TextStyle applyHeader(TextStyle base) {
    return headerFont(
      textStyle: base,
      fontWeight: base.fontWeight,
      fontSize: base.fontSize,
      height: base.height,
      letterSpacing: base.letterSpacing,
      fontStyle: base.fontStyle,
      color: base.color,
    );
  }

  TextStyle applyBody(TextStyle base) {
    return bodyFont(
      textStyle: base,
      fontWeight: base.fontWeight,
      fontSize: base.fontSize,
      height: base.height,
      letterSpacing: base.letterSpacing,
      fontStyle: base.fontStyle,
      color: base.color,
    );
  }

  @override
  bool operator ==(Object other) => other is FontPairing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Curated pairings. Modern Tech is free; the other three are Pro.
abstract final class FontPairings {
  static final FontPairing modernTech = FontPairing(
    id: 'modern_tech',
    name: 'Modern Tech',
    headerFont: GoogleFonts.inter,
    bodyFont: GoogleFonts.jetBrainsMono,
    headerFamily: 'Inter',
    bodyFamily: 'JetBrains Mono',
    isPro: false,
  );

  static final FontPairing editorialAuthority = FontPairing(
    id: 'editorial_authority',
    name: 'Editorial Authority',
    headerFont: GoogleFonts.playfairDisplay,
    bodyFont: GoogleFonts.plusJakartaSans,
    headerFamily: 'Playfair Display',
    bodyFamily: 'Plus Jakarta Sans',
    isPro: true,
  );

  static final FontPairing highImpact = FontPairing(
    id: 'high_impact',
    name: 'High Impact',
    headerFont: _montserratHeadline,
    bodyFont: GoogleFonts.openSans,
    headerFamily: 'Montserrat',
    bodyFamily: 'Open Sans',
    isPro: true,
  );

  static final FontPairing minimalist = FontPairing(
    id: 'minimalist',
    name: 'Minimalist',
    headerFont: GoogleFonts.spaceGrotesk,
    bodyFont: GoogleFonts.dmSans,
    headerFamily: 'Space Grotesk',
    bodyFamily: 'DM Sans',
    isPro: true,
  );

  static final List<FontPairing> all = <FontPairing>[
    modernTech,
    editorialAuthority,
    highImpact,
    minimalist,
  ];

  static FontPairing? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final pairing in all) {
      if (pairing.id == id) return pairing;
    }
    return null;
  }

  /// Pro pairings resolve to null unless [isProPurchased] (or demo bypass).
  static FontPairing? resolve(
    String? id, {
    required bool isProPurchased,
  }) {
    final pairing = byId(id);
    if (pairing == null) return null;
    if (pairing.isPro && !canAccessProFeature(isProPurchased: isProPurchased)) {
      return null;
    }
    return pairing;
  }

  /// Google Fonts method for a family used by card type, if one is curated.
  static GoogleFontMethod? methodForFamily(String family) {
    for (final pairing in all) {
      if (pairing.headerFamily == family) return pairing.headerFont;
    }
    for (final pairing in all) {
      if (pairing.bodyFamily == family) return pairing.bodyFont;
    }
    return null;
  }
}

/// High Impact headlines stay bold even when a caller asks for a lighter weight.
TextStyle _montserratHeadline({
  TextStyle? textStyle,
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
}) {
  final requested = fontWeight ?? textStyle?.fontWeight ?? FontWeight.w700;
  final weight = requested.value < FontWeight.w700.value
      ? FontWeight.w700
      : requested;
  return GoogleFonts.montserrat(
    textStyle: textStyle,
    color: color,
    fontSize: fontSize,
    fontWeight: weight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Headline vs body family for the widgets inside a [CardCanvas].
class CardTypography extends InheritedWidget {
  const CardTypography({
    super.key,
    required this.headerFamily,
    required this.bodyFamily,
    required super.child,
  });

  final String headerFamily;
  final String bodyFamily;

  static CardTypography? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardTypography>();
  }

  @override
  bool updateShouldNotify(CardTypography oldWidget) {
    return headerFamily != oldWidget.headerFamily ||
        bodyFamily != oldWidget.bodyFamily;
  }
}
