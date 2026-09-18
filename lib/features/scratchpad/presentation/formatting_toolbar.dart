import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/markdown_formatter.dart';

/// Keyboard accessory that inserts markdown tokens so users never type syntax.
class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    this.onTextChanged,
    this.formatter = const MarkdownFormatter(),
  });

  final TextEditingController controller;
  final ValueChanged<String>? onTextChanged;
  final MarkdownFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: colors.onSurface,
    );

    return ExcludeFocus(
      child: Material(
        key: const Key('formatting-toolbar'),
        color: colors.surfaceContainerLowest,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FormatButton(
                            buttonKey: const Key('format-bold'),
                            semanticLabel: 'Bold',
                            onTap: () => _run(formatter.toggleBold),
                            child: Text(
                              'B',
                              style: labelStyle.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _FormatButton(
                            buttonKey: const Key('format-italic'),
                            semanticLabel: 'Italic',
                            onTap: () => _run(formatter.toggleItalic),
                            child: Text(
                              'I',
                              style: labelStyle.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _FormatButton(
                            buttonKey: const Key('format-heading'),
                            semanticLabel: 'Heading',
                            onTap: () => _run(formatter.cycleHeading),
                            child: Text('H', style: labelStyle),
                          ),
                          _FormatButton(
                            buttonKey: const Key('format-bullet'),
                            semanticLabel: 'Bullet list',
                            onTap: () => _run(formatter.toggleBullet),
                            child: Text('•=', style: labelStyle),
                          ),
                          _FormatButton(
                            buttonKey: const Key('format-quote'),
                            semanticLabel: 'Quote',
                            onTap: () => _run(formatter.toggleQuote),
                            child: Text('”', style: labelStyle),
                          ),
                          _FormatButton(
                            buttonKey: const Key('format-code'),
                            semanticLabel: 'Code',
                            onTap: () => _run(formatter.toggleCode),
                            child: Text(
                              '</>',
                              style: labelStyle.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _SlideBreakButton(
                      onTap: () => _run(formatter.insertSlideBreak),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _run(
    MarkdownEditResult Function(String text, int start, int end) action,
  ) {
    HapticFeedback.selectionClick();
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final result = action(text, start, end);
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.selectionStart,
        extentOffset: result.selectionEnd,
      ),
    );
    onTextChanged?.call(result.text);
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.buttonKey,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final Key buttonKey;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: buttonKey,
      button: true,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 40,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideBreakButton extends StatelessWidget {
  const _SlideBreakButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('format-slide'),
      button: true,
      label: 'Add slide',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Material(
          color: colors.primary,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  '+ Slide',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
