import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../exporter/presentation/card_exporter_screen.dart';
import '../../exporter/state/card_settings.dart';
import '../state/scratchpad_notifier.dart';
import 'export_actions.dart';

/// Platform export bar docked above the software keyboard / status strip.
///
/// Transformations run in-memory at copy time and never overwrite the editor.
class ExportToolbar extends ConsumerWidget {
  const ExportToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scratchpadProvider);
    final canExport = !PlatformExporter.isEmptyDraft(state.content);
    final overXLimit = state.charCount > PlatformExporter.xCharLimit;
    final colors = Theme.of(context).colorScheme;

    return Material(
      key: const Key('export-toolbar'),
      color: colors.surfaceContainerLowest,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ExportAction(
                    buttonKey: const Key('export-linkedin'),
                    icon: Icons.work_outline,
                    label: 'LinkedIn',
                    enabled: canExport,
                    onPressed: () => _copyLinkedIn(context, ref),
                  ),
                  _ExportAction(
                    buttonKey: const Key('export-x-threads'),
                    icon: Icons.alternate_email,
                    label: 'X / Threads',
                    enabled: canExport,
                    showAmber: overXLimit,
                    onPressed: () => _openXThreadsSheet(context, ref),
                  ),
                  _ExportAction(
                    buttonKey: const Key('export-substack'),
                    icon: Icons.auto_stories_outlined,
                    label: 'Substack',
                    enabled: canExport,
                    onPressed: () => _copySubstack(context, ref),
                  ),
                  _ExportAction(
                    buttonKey: const Key('export-card'),
                    icon: Icons.view_carousel_outlined,
                    label: 'Card',
                    enabled: true,
                    onPressed: () => _openCardExporter(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyLinkedIn(BuildContext context, WidgetRef ref) async {
    await _runCopy(
      context,
      ref,
      copy: (exporter, markdown) => exporter.copyForLinkedIn(markdown),
      message: ExportMessages.linkedIn,
    );
  }

  Future<void> _copySubstack(BuildContext context, WidgetRef ref) async {
    await _runCopy(
      context,
      ref,
      copy: (exporter, markdown) => exporter.copyForSubstack(markdown),
      message: ExportMessages.substack,
    );
  }

  Future<void> _runCopy(
    BuildContext context,
    WidgetRef ref, {
    required Future<bool> Function(PlatformExporter exporter, String markdown)
        copy,
    required String message,
  }) async {
    final markdown = ref.read(scratchpadProvider).content;
    unawaited(HapticFeedback.lightImpact());
    final exported = await copy(ref.read(platformExporterProvider), markdown);
    if (!exported || !context.mounted) return;
    _showCopiedSnackBar(context, message);
  }

  Future<void> _openXThreadsSheet(BuildContext context, WidgetRef ref) async {
    final markdown = ref.read(scratchpadProvider).content;
    if (PlatformExporter.isEmptyDraft(markdown)) return;

    final charCount = ref.read(scratchpadProvider).charCount;
    final exporter = ref.read(platformExporterProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _XThreadsExportSheet(
          markdown: markdown,
          charCount: charCount,
          exporter: exporter,
        );
      },
    );
  }

  void _openCardExporter(BuildContext context, WidgetRef ref) {
    final draft = ref.read(scratchpadProvider).content;
    final author = ref.read(cardSettingsProvider).formattedAuthor;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardExporterScreen(text: draft, author: author),
      ),
    );
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.showAmber = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool showAmber;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = colors.onSurface.withValues(alpha: enabled ? 0.85 : 0.32);
    final labelStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: ink,
    );

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          key: buttonKey,
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: ink),
                    if (showAmber)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(
                          key: const Key('x-limit-indicator'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XThreadsExportSheet extends StatelessWidget {
  const _XThreadsExportSheet({
    required this.markdown,
    required this.charCount,
    required this.exporter,
  });

  final String markdown;
  final int charCount;
  final PlatformExporter exporter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleStyle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );
    final captionStyle = GoogleFonts.inter(
      fontSize: 13,
      height: 1.4,
      color: colors.onSurface.withValues(alpha: 0.55),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Copy for X / Threads', style: titleStyle),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$charCount characters · draft stays unchanged',
                style: captionStyle,
              ),
            ),
            const SizedBox(height: 12),
            _DestinationTile(
              tileKey: const Key('export-copy-x'),
              title: 'X (Twitter)',
              charCount: charCount,
              limit: PlatformExporter.xCharLimit,
              onTap: () => _copyAndClose(
                context,
                copy: () => exporter.copyForX(markdown),
                message: ExportMessages.x,
              ),
            ),
            _DestinationTile(
              tileKey: const Key('export-copy-threads'),
              title: 'Threads',
              charCount: charCount,
              limit: PlatformExporter.threadsCharLimit,
              onTap: () => _copyAndClose(
                context,
                copy: () => exporter.copyForThreads(markdown),
                message: ExportMessages.threads,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAndClose(
    BuildContext context, {
    required Future<bool> Function() copy,
    required String message,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.lightImpact());
    final exported = await copy();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!exported) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_copiedSnackBar(message));
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.tileKey,
    required this.title,
    required this.charCount,
    required this.limit,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final int charCount;
  final int limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overLimit = charCount > limit;
    final colors = Theme.of(context).colorScheme;
    final countColor =
        overLimit ? Colors.amber.shade800 : colors.onSurface.withValues(alpha: 0.55);

    return ListTile(
      key: tileKey,
      onTap: onTap,
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: Text(
        '$charCount / $limit',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: countColor,
        ),
      ),
    );
  }
}

SnackBar _copiedSnackBar(String message) {
  return SnackBar(
    content: Text(
      message,
      style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
    ),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

void _showCopiedSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(_copiedSnackBar(message));
}
