import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../templates/card_theme_config.dart';

/// Customization panel for the card exporter. Currently hosts the Pro
/// photo-backdrop picker, blur, dimmer, and scrim controls.
class CardCustomizerControls extends StatelessWidget {
  const CardCustomizerControls({
    super.key,
    required this.theme,
    required this.isProPurchased,
    required this.canAccessPro,
    required this.onChanged,
    required this.onPickPhoto,
    required this.onLockedFeature,
    this.enabled = true,
  });

  final CardThemeConfig theme;
  final bool isProPurchased;
  final bool canAccessPro;
  final ValueChanged<CardThemeConfig> onChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onLockedFeature;
  final bool enabled;

  bool get _hasPhoto => theme.hasCustomBackground;

  void _requestPick() {
    if (!enabled) return;
    if (!canAccessPro) {
      onLockedFeature();
      return;
    }
    onPickPhoto();
  }

  void _removePhoto() {
    if (!enabled) return;
    onChanged(theme.copyWith(customBackgroundImagePath: null));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Column(
      key: const Key('photo-backdrop-card'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('photo-backdrop-choose'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
          title: Text('Photo Backdrop', style: labelStyle),
          secondary: Icon(
            isProPurchased ? Icons.photo_outlined : Icons.lock_outline,
            key: isProPurchased ? null : const Key('photo-backdrop-lock'),
            size: 20,
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
          value: _hasPhoto,
          onChanged: !enabled
              ? null
              : (on) {
                  if (on) {
                    _requestPick();
                  } else {
                    _removePhoto();
                  }
                },
        ),
        if (_hasPhoto)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                _LabeledSlider(
                  key: const Key('photo-backdrop-blur'),
                  label: 'Blur',
                  valueLabel: theme.resolvedBlurSigma.round().toString(),
                  value: theme.resolvedBlurSigma,
                  min: CardThemeConfig.minBlurSigma,
                  max: CardThemeConfig.maxBlurSigma,
                  divisions: CardThemeConfig.maxBlurSigma.round(),
                  onChanged: enabled
                      ? (value) => onChanged(theme.copyWith(blurSigma: value))
                      : null,
                ),
                _LabeledSlider(
                  key: const Key('photo-backdrop-dimmer'),
                  label: 'Dimmer',
                  valueLabel:
                      '${(theme.resolvedOverlayOpacity * 100).round()}%',
                  value: theme.resolvedOverlayOpacity,
                  min: CardThemeConfig.minOverlayOpacity,
                  max: CardThemeConfig.maxOverlayOpacity,
                  divisions: 13,
                  onChanged: enabled
                      ? (value) =>
                          onChanged(theme.copyWith(overlayOpacity: value))
                      : null,
                ),
                const SizedBox(height: 2),
                SegmentedButton<bool>(
                  key: const Key('photo-backdrop-scrim-toggle'),
                  segments: [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(
                        'Dark',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      icon: const Icon(Icons.dark_mode_outlined, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(
                        'Light',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      icon: const Icon(Icons.light_mode_outlined, size: 16),
                    ),
                  ],
                  selected: {theme.isDarkOverlay},
                  onSelectionChanged: !enabled
                      ? null
                      : (next) {
                          if (next.isEmpty) return;
                          onChanged(theme.copyWith(isDarkOverlay: next.single));
                        },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: WidgetStatePropertyAll(
                      GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.onSurface.withValues(alpha: 0.65),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(label, style: style),
            const Spacer(),
            Text(valueLabel, style: style),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
