import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import 'quill_formatting.dart';

/// Keyboard accessory that applies rich-text formatting without inserting
/// markdown tokens into the visible document.
class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    this.onOpenTemplates,
  });

  final QuillController controller;

  /// Opens the framework template drawer. Kept off the Quill focus node.
  final VoidCallback? onOpenTemplates;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextFieldTapRegion(
      child: ExcludeFocus(
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
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final style = controller.getSelectionStyle();
                      final header =
                          style.attributes[Attribute.header.key]?.value;
                      return Row(
                        children: [
                          Expanded(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _FormatButton(
                                  buttonKey: const Key('format-bold'),
                                  activeKey: const Key('format-bold-active'),
                                  semanticLabel: 'Bold',
                                  active: _isOn(style, Attribute.bold),
                                  emphasize: FontWeight.w800,
                                  onTap: () => _run(
                                    () => toggleQuillAttribute(
                                      controller,
                                      Attribute.bold,
                                    ),
                                  ),
                                  child: const Text('B'),
                                ),
                                _FormatButton(
                                  buttonKey: const Key('format-italic'),
                                  activeKey: const Key('format-italic-active'),
                                  semanticLabel: 'Italic',
                                  active: _isOn(style, Attribute.italic),
                                  italic: true,
                                  onTap: () => _run(
                                    () => toggleQuillAttribute(
                                      controller,
                                      Attribute.italic,
                                    ),
                                  ),
                                  child: const Text('I'),
                                ),
                                _FormatButton(
                                  buttonKey: const Key('format-heading'),
                                  activeKey: const Key('format-heading-active'),
                                  semanticLabel: 'Heading',
                                  active: header is num && header > 0,
                                  onTap: () =>
                                      _run(() => cycleQuillHeading(controller)),
                                  child: const Text('H'),
                                ),
                                _FormatButton(
                                  buttonKey: const Key('format-bullet'),
                                  activeKey: const Key('format-bullet-active'),
                                  semanticLabel: 'Bullet list',
                                  active: _isOn(style, Attribute.ul),
                                  onTap: () => _run(
                                    () => toggleQuillAttribute(
                                      controller,
                                      Attribute.ul,
                                    ),
                                  ),
                                  child: const Text('•'),
                                ),
                                _FormatButton(
                                  buttonKey: const Key('format-quote'),
                                  activeKey: const Key('format-quote-active'),
                                  semanticLabel: 'Quote',
                                  active: _isOn(style, Attribute.blockQuote),
                                  onTap: () => _run(
                                    () => toggleQuillAttribute(
                                      controller,
                                      Attribute.blockQuote,
                                    ),
                                  ),
                                  child: const Text('”'),
                                ),
                                _FormatButton(
                                  buttonKey: const Key('format-code'),
                                  activeKey: const Key('format-code-active'),
                                  semanticLabel: 'Code',
                                  active:
                                      _isOn(style, Attribute.inlineCode) ||
                                      _isOn(style, Attribute.codeBlock),
                                  monospace: true,
                                  onTap: () =>
                                      _run(() => toggleQuillCode(controller)),
                                  child: const Text('</>'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _FormatButton(
                            buttonKey: const Key('format-templates'),
                            activeKey: const Key('format-templates-active'),
                            semanticLabel: 'Framework templates',
                            active: false,
                            onTap: () => _run(() => onOpenTemplates?.call()),
                            child: const Icon(Icons.auto_awesome, size: 18),
                          ),
                          _SlideBreakButton(
                            onTap: () => _run(
                              () => insertQuillSlideBreak(controller),
                              heavy: true,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOn(Style style, Attribute attribute) {
    final current = style.attributes[attribute.key];
    return current != null && current.value == attribute.value;
  }

  void _run(VoidCallback action, {bool heavy = false}) {
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    action();
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.buttonKey,
    required this.activeKey,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    required this.active,
    this.emphasize,
    this.italic = false,
    this.monospace = false,
  });

  final Key buttonKey;
  final Key activeKey;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool active;
  final FontWeight? emphasize;
  final bool italic;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseStyle = GoogleFonts.inter(
      fontSize: monospace ? 13 : 15,
      fontWeight: emphasize ?? FontWeight.w600,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: 0.2,
      color: active ? colors.primary : colors.onSurface,
    );
    final labelStyle = monospace
        ? baseStyle.copyWith(fontFamily: 'monospace')
        : baseStyle;

    return Semantics(
      key: buttonKey,
      button: true,
      label: semanticLabel,
      selected: active,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              key: active ? activeKey : null,
              width: 40,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: active
                    ? colors.primary.withValues(alpha: 0.16)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: labelStyle.color),
                  child: DefaultTextStyle.merge(
                    style: labelStyle,
                    child: child,
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
