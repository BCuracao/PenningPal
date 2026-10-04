import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

/// PenningPal typography for the scratchpad rich-text editor.
DefaultStyles scratchpadEditorStyles(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final ink = colors.onSurface;
  final body = GoogleFonts.inter(
    fontSize: 17,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: ink,
  );

  DefaultTextBlockStyle block(
    TextStyle style, {
    HorizontalSpacing horizontal = HorizontalSpacing.zero,
    VerticalSpacing vertical = const VerticalSpacing(2, 2),
    BoxDecoration? decoration,
  }) {
    return DefaultTextBlockStyle(
      style,
      horizontal,
      vertical,
      VerticalSpacing.zero,
      decoration,
    );
  }

  return DefaultStyles(
    h1: block(
      GoogleFonts.inter(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      vertical: const VerticalSpacing(8, 4),
    ),
    h2: block(
      GoogleFonts.inter(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      vertical: const VerticalSpacing(6, 2),
    ),
    h3: block(
      GoogleFonts.inter(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    paragraph: block(body),
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    lists: DefaultListBlockStyle(
      body,
      const HorizontalSpacing(6, 0),
      const VerticalSpacing(2, 2),
      VerticalSpacing.zero,
      null,
      null,
    ),
    quote: block(
      body.copyWith(
        fontStyle: FontStyle.italic,
        color: ink.withValues(alpha: 0.88),
      ),
      horizontal: const HorizontalSpacing(14, 0),
      vertical: const VerticalSpacing(6, 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        border: Border(
          left: BorderSide(
            width: 3,
            color: colors.primary.withValues(alpha: 0.75),
          ),
        ),
      ),
    ),
    placeHolder: block(
      body.copyWith(color: ink.withValues(alpha: 0.35)),
    ),
  );
}
