import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cta_qr_code_widget.dart';

/// URL field and toggle shown only while the active slide is a CTA.
class CtaQrControls extends StatelessWidget {
  const CtaQrControls({
    super.key,
    required this.controller,
    required this.showQrCode,
    required this.onShowQrCode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool showQrCode;
  final ValueChanged<bool> onShowQrCode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final payload = CtaQrDestination.payloadFor(controller.text);
    final needsLink = showQrCode && payload == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        key: const Key('cta-qr-panel'),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  key: const Key('cta-qr-toggle'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                  title: Text(
                    'Show QR Code on CTA slide',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  value: showQrCode,
                  onChanged: enabled ? onShowQrCode : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  key: const Key('cta-qr-url'),
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Destination URL',
                    hintText: 'https://linkedin.com/in/your-name',
                    labelStyle: GoogleFonts.inter(fontSize: 13),
                    hintStyle: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ),
              if (needsLink)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Text(
                    controller.text.trim().isEmpty
                        ? 'Add a link to show the QR code.'
                        : 'Enter a valid http(s) link.',
                    key: const Key('cta-qr-invalid'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
