import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Normalizes a CTA destination and rejects strings that cannot be a QR link.
abstract final class CtaQrDestination {
  static const int maxLength = 1024;

  /// `http(s)` URL safe to encode, or null when [raw] should not become a QR.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty || value.length > maxLength) return null;
    if (RegExp(r'[\s\u0000-\u001F]').hasMatch(value)) return null;
    if (value.contains('<') || value.contains('>') || value.contains('"')) {
      return null;
    }

    final hasHttp = RegExp(r'^https?://', caseSensitive: false).hasMatch(value);
    if (!hasHttp) {
      if (value.contains(':') || value.contains('//') || !value.contains('.')) {
        return null;
      }
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;
    if (uri.toString().length > maxLength) return null;
    return uri.toString();
  }

  /// [normalize] plus a QR capacity check. Null means the canvas shows a fallback.
  static String? payloadFor(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    final result = QrValidator.validate(data: normalized);
    if (!result.isValid) return null;
    return normalized;
  }
}

/// Plate behind the modules so a light-on-light or dark-on-dark code still scans.
Color ctaQrPlateColor({
  required Color foreground,
  required Color accent,
}) {
  final base = foreground.computeLuminance() > 0.55
      ? const Color(0xFF111827)
      : const Color(0xFFFFFFFF);
  return Color.alphaBlend(accent.withValues(alpha: 0.16), base);
}

/// QR mark for a CTA slide. Invalid destinations paint a fallback, not a throw.
class CtaQrCodeWidget extends StatelessWidget {
  const CtaQrCodeWidget({
    super.key,
    required this.destination,
    required this.foregroundColor,
    required this.accentColor,
    this.size = 168,
  });

  final String? destination;

  /// Module color. Callers pass the card theme text color.
  final Color foregroundColor;

  /// Tints the quiet-zone plate so the code matches the card.
  final Color accentColor;

  final double size;

  @override
  Widget build(BuildContext context) {
    final payload = CtaQrDestination.payloadFor(destination);
    if (payload == null) {
      return _CtaQrFallback(
        size: size,
        foregroundColor: foregroundColor,
        accentColor: accentColor,
      );
    }

    final plate = ctaQrPlateColor(
      foreground: foregroundColor,
      accent: accentColor,
    );
    return SizedBox(
      key: const Key('cta-qr-image'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plate,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: size,
            padding: const EdgeInsets.all(10),
            gapless: true,
            backgroundColor: plate,
            semanticsLabel: 'QR code',
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: foregroundColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: foregroundColor,
            ),
            errorStateBuilder: (context, error) => _CtaQrFallback(
              size: size,
              foregroundColor: foregroundColor,
              accentColor: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaQrFallback extends StatelessWidget {
  const _CtaQrFallback({
    required this.size,
    required this.foregroundColor,
    required this.accentColor,
  });

  final double size;
  final Color foregroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('cta-qr-fallback'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ctaQrPlateColor(
            foreground: foregroundColor,
            accent: accentColor,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: foregroundColor.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.qr_code_2,
          size: size * 0.46,
          color: foregroundColor.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
