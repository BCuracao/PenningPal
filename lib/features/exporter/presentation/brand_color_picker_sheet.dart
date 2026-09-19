import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../templates/card_theme_config.dart';

/// Pro Custom Brand picker: 12 swatches, hex fields, and a color wheel.
class BrandColorPickerSheet extends StatefulWidget {
  const BrandColorPickerSheet({
    super.key,
    required this.backgroundColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color textColor;

  static Future<({Color background, Color text})?> show(
    BuildContext context, {
    required Color backgroundColor,
    required Color textColor,
  }) {
    return showModalBottomSheet<({Color background, Color text})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => BrandColorPickerSheet(
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
    );
  }

  @override
  State<BrandColorPickerSheet> createState() => _BrandColorPickerSheetState();
}

class _BrandColorPickerSheetState extends State<BrandColorPickerSheet> {
  late Color _background;
  late Color _text;
  late final TextEditingController _backgroundHex;
  late final TextEditingController _textHex;
  bool _pickingBackground = true;

  @override
  void initState() {
    super.initState();
    _background = widget.backgroundColor;
    _text = widget.textColor;
    _backgroundHex = TextEditingController(text: HexColor.format(_background));
    _textHex = TextEditingController(text: HexColor.format(_text));
  }

  @override
  void dispose() {
    _backgroundHex.dispose();
    _textHex.dispose();
    super.dispose();
  }

  Color get _active => _pickingBackground ? _background : _text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('brand-color-picker'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Custom Brand Colors',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TargetChip(
                    selected: _pickingBackground,
                    label: 'Background',
                    color: _background,
                    onTap: () => setState(() => _pickingBackground = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TargetChip(
                    selected: !_pickingBackground,
                    label: 'Text',
                    color: _text,
                    onTap: () => setState(() => _pickingBackground = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              key: const Key('brand-color-swatches'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in BrandColorSwatches.all)
                  _SwatchDot(
                    color: swatch,
                    selected: _active.toARGB32() == swatch.toARGB32(),
                    onTap: () => _applySwatch(swatch),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ColorPicker(
              pickerColor: _active,
              onColorChanged: _applySwatch,
              enableAlpha: false,
              hexInputBar: true,
              portraitOnly: true,
              colorPickerWidth: 280,
              pickerAreaHeightPercent: 0.55,
              labelTypes: const [],
              displayThumbColor: true,
              pickerAreaBorderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('brand-hex-background'),
              controller: _backgroundHex,
              decoration: const InputDecoration(
                labelText: 'Background hex',
                border: OutlineInputBorder(),
                prefixText: '',
              ),
              onChanged: (value) {
                final parsed = HexColor.tryParse(value);
                if (parsed == null) return;
                setState(() => _background = parsed);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('brand-hex-text'),
              controller: _textHex,
              decoration: const InputDecoration(
                labelText: 'Text hex',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = HexColor.tryParse(value);
                if (parsed == null) return;
                setState(() => _text = parsed);
              },
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Text(
                  'Aa Preview',
                  key: const Key('brand-color-preview'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('brand-color-apply'),
              onPressed: () => Navigator.of(context).pop(
                (background: _background, text: _text),
              ),
              child: const Text('Apply colors'),
            ),
          ],
        ),
      ),
    );
  }

  void _applySwatch(Color color) {
    setState(() {
      if (_pickingBackground) {
        _background = color;
        _backgroundHex.text = HexColor.format(color);
      } else {
        _text = color;
        _textHex.text = HexColor.format(color);
      }
    });
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.selected,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}
