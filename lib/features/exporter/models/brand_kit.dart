import 'dart:math';

import 'package:flutter/material.dart';

import '../templates/card_theme_config.dart';

/// Reusable card identity: palette, type pairing, optional logo, and ratio.
class BrandKit {
  BrandKit({
    required this.id,
    required String name,
    required String primaryColor,
    required String secondaryColor,
    required this.fontPairingId,
    String? logoPath,
    this.aspectRatio = CardAspectRatio.square,
  }) : name = _cleanName(name),
       primaryColor = normalizeBrandHex(primaryColor, fallback: '#0F172A'),
       secondaryColor = normalizeBrandHex(secondaryColor, fallback: '#F8FAFC'),
       logoPath = _cleanLogo(logoPath);

  /// Stable id. New kits use [generateBrandKitId].
  final String id;

  /// Display name, e.g. "Personal Brand" or "Company".
  final String name;

  /// Background hex (`#RRGGBB`).
  final String primaryColor;

  /// Type / accent hex (`#RRGGBB`).
  final String secondaryColor;

  /// Curated font pairing id (`modern_tech`, `editorial_authority`, ...).
  final String fontPairingId;

  /// On-device logo file. Never uploaded.
  final String? logoPath;

  final CardAspectRatio aspectRatio;

  Color get primary => HexColor.parse(primaryColor);

  Color get secondary => HexColor.parse(secondaryColor);

  BrandKit copyWith({
    String? id,
    String? name,
    String? primaryColor,
    String? secondaryColor,
    String? fontPairingId,
    Object? logoPath = _keepLogo,
    CardAspectRatio? aspectRatio,
  }) {
    return BrandKit(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      fontPairingId: fontPairingId ?? this.fontPairingId,
      logoPath: identical(logoPath, _keepLogo) ? this.logoPath : logoPath as String?,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'fontPairingId': fontPairingId,
      'logoPath': logoPath,
      'aspectRatio': aspectRatio.name,
    };
  }

  static BrandKit fromMap(Map<dynamic, dynamic> map) {
    final ratioName = map['aspectRatio'] as String?;
    return BrandKit(
      id: map['id'] as String? ?? generateBrandKitId(),
      name: map['name'] as String? ?? 'Personal Brand',
      primaryColor: map['primaryColor'] as String? ?? '#0F172A',
      secondaryColor: map['secondaryColor'] as String? ?? '#F8FAFC',
      fontPairingId: map['fontPairingId'] as String? ?? 'modern_tech',
      logoPath: map['logoPath'] as String?,
      aspectRatio: CardAspectRatio.values.firstWhere(
        (ratio) => ratio.name == ratioName,
        orElse: () => CardAspectRatio.square,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BrandKit &&
        other.id == id &&
        other.name == name &&
        other.primaryColor == primaryColor &&
        other.secondaryColor == secondaryColor &&
        other.fontPairingId == fontPairingId &&
        other.logoPath == logoPath &&
        other.aspectRatio == aspectRatio;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    primaryColor,
    secondaryColor,
    fontPairingId,
    logoPath,
    aspectRatio,
  );
}

const Object _keepLogo = Object();

final Random _brandKitIdRandom = Random();

String generateBrandKitId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final entropy = _brandKitIdRandom.nextInt(0x7fffffff).toRadixString(16);
  return 'kit_${now}_$entropy';
}

/// `#RGB`, `#RRGGBB`, and `#AARRGGBB` become uppercase `#RRGGBB`.
String normalizeBrandHex(String input, {required String fallback}) {
  final parsed = HexColor.tryParse(input);
  if (parsed == null) return fallback;
  return HexColor.format(parsed);
}

String _cleanName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Personal Brand' : trimmed;
}

String? _cleanLogo(String? path) {
  final trimmed = path?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Paints a kit onto the active card theme.
///
/// [BrandKit.primaryColor] fills the background. [BrandKit.secondaryColor]
/// becomes the type color when it stays readable, and always tints the accent.
abstract final class BrandPalette {
  static CardThemeConfig apply(CardThemeConfig theme, BrandKit kit) {
    final background = kit.primary;
    final preferred = kit.secondary;
    return theme.withBrandPalette(
      backgroundColor: background,
      textColor: readableText(background, preferred),
      accentColor: preferred,
    );
  }

  /// [preferred] when it clears a 3:1 contrast bar, otherwise ink or paper.
  static Color readableText(Color background, Color preferred) {
    if (_contrast(background, preferred) >= 3) return preferred;
    return background.computeLuminance() > 0.55
        ? const Color(0xFF1F2937)
        : const Color(0xFFF8FAFC);
  }

  static double _contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
