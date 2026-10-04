import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../render/markdown_quill_bridge.dart';

/// Paints a slide divider as a banner instead of the stored `---` rule.
class SlideBreakEmbedBuilder extends EmbedBuilder {
  const SlideBreakEmbedBuilder();

  @override
  String get key => SlideBreakEmbed.embedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final number = _slideNumber(embedContext);
    final colors = Theme.of(context).colorScheme;
    final label = '── Slide Break $number ──';

    return Padding(
      key: Key('slide-break-$number'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.85),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.onSurface.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: colors.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.onSurface.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _slideNumber(EmbedContext embedContext) {
  final target = embedContext.node.documentOffset;
  var count = 0;
  var position = 0;
  for (final op in embedContext.controller.document.toDelta().toList()) {
    final data = op.data;
    final length = data is String ? data.length : 1;
    if (isSlideBreakEmbed(data)) {
      count++;
      if (position >= target) return count;
    }
    position += length;
  }
  return count == 0 ? 1 : count;
}
