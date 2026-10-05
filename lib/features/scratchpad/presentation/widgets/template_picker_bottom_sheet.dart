import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/framework_templates.dart';

/// Bottom sheet of post frameworks. Blank drafts insert immediately.
///
/// A draft that already has text asks whether to append or replace before
/// the Markdown buffer changes.
class TemplatePickerBottomSheet extends StatelessWidget {
  const TemplatePickerBottomSheet({
    super.key,
    required this.currentMarkdown,
    required this.onApply,
  });

  final String currentMarkdown;
  final ValueChanged<String> onApply;

  static Future<void> show(
    BuildContext context, {
    required String currentMarkdown,
    required ValueChanged<String> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return TemplatePickerBottomSheet(
          currentMarkdown: currentMarkdown,
          onApply: (markdown) {
            Navigator.of(sheetContext).pop();
            onApply(markdown);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frameworks',
              key: const Key('template-picker-sheet'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Drop in a structure. Slide breaks stay as ---.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            for (final template in FrameworkTemplates.all)
              _TemplateTile(
                template: template,
                onTap: () => _choose(context, template),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, FrameworkTemplate template) async {
    final mode = FrameworkTemplates.isBlank(currentMarkdown)
        ? TemplateInsertMode.replace
        : await _confirm(context);
    if (mode == null || !context.mounted) return;
    onApply(
      FrameworkTemplates.apply(
        current: currentMarkdown,
        template: template,
        mode: mode,
      ),
    );
  }

  Future<TemplateInsertMode?> _confirm(BuildContext context) {
    return showDialog<TemplateInsertMode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('template-insert-dialog'),
          title: Text(
            'This draft already has text',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Keep what you wrote, or start over with the framework.',
            style: GoogleFonts.inter(height: 1.4),
          ),
          actions: [
            TextButton(
              key: const Key('template-append'),
              onPressed: () => Navigator.of(dialogContext).pop(
                TemplateInsertMode.append,
              ),
              child: const Text('Append to existing text'),
            ),
            FilledButton(
              key: const Key('template-replace'),
              onPressed: () => Navigator.of(dialogContext).pop(
                TemplateInsertMode.replace,
              ),
              child: const Text('Replace current draft'),
            ),
          ],
        );
      },
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final FrameworkTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('template-${template.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.blurb,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: colors.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
