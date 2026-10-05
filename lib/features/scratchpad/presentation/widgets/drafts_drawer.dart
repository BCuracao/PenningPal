import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../exporter/models/carousel_deck.dart';
import '../../models/draft_item.dart';
import '../../state/draft_presentation.dart';
import '../../state/draft_providers.dart';
import '../../state/scratchpad_notifier.dart';
import '../../state/scratchpad_state.dart';

/// Slide-out workspace for switching, searching, and organizing local drafts.
class DraftsDrawer extends ConsumerStatefulWidget {
  const DraftsDrawer({
    super.key,
    this.onNewDraft,
    this.onOpenSettings,
  });

  final VoidCallback? onNewDraft;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<DraftsDrawer> createState() => _DraftsDrawerState();
}

class _DraftsDrawerState extends ConsumerState<DraftsDrawer> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(draftSearchQueryProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final drafts = ref.watch(draftListProvider);
    final visible = ref.watch(filteredDraftsProvider);
    final activeId = ref.watch(scratchpadProvider).activeDraftId;
    final statusFilter = ref.watch(draftStatusFilterProvider);
    final query = ref.watch(draftSearchQueryProvider).trim();
    final filtering =
        query.isNotEmpty || statusFilter != DraftStatusFilter.all;

    return Drawer(
      key: const Key('drafts-drawer'),
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(draftCount: drafts.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilledButton.icon(
                key: const Key('drafts-new-post'),
                onPressed: widget.onNewDraft,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'New Draft',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('drafts-search'),
                controller: _search,
                onChanged: (value) {
                  ref.read(draftSearchQueryProvider.notifier).setQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search drafts',
                  hintStyle: GoogleFonts.inter(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: DraftStatusFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = DraftStatusFilter.values[index];
                  return ChoiceChip(
                    key: Key('draft-filter-${filter.name}'),
                    label: Text(
                      filter.label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: statusFilter == filter,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      ref.read(draftStatusFilterProvider.notifier).select(filter);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        filtering ? 'No matching drafts' : 'No drafts yet',
                        key: const Key('drafts-empty'),
                        style: GoogleFonts.inter(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final draft = visible[index];
                        return _DraftTile(
                          draft: draft,
                          isActive: draft.id == activeId,
                          onTap: () async {
                            await ref
                                .read(activeDraftIdProvider.notifier)
                                .select(draft.id);
                            if (context.mounted) {
                              Navigator.of(context).maybePop();
                            }
                          },
                          onOpenActions: () => _openActions(draft),
                          onDelete: () => _deleteWithUndo(draft),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('drafts-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: Text(
                'Settings & Profile',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onTap: widget.onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openActions(DraftItem draft) async {
    final action = await showDraftActions(context, draft);
    if (action == null || !mounted) return;
    switch (action) {
      case DraftAction.duplicate:
        final copy = await ref
            .read(scratchpadProvider.notifier)
            .duplicateDraftById(draft.id);
        if (!mounted || copy == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicated “${copy.title}”')),
        );
      case DraftAction.delete:
        await _deleteWithUndo(draft);
      case DraftAction.markDraft:
        await ref
            .read(scratchpadProvider.notifier)
            .setDraftStatus(draft.id, DraftStatus.draft);
      case DraftAction.markReady:
        await ref
            .read(scratchpadProvider.notifier)
            .setDraftStatus(draft.id, DraftStatus.ready);
      case DraftAction.markPublished:
        await ref
            .read(scratchpadProvider.notifier)
            .setDraftStatus(draft.id, DraftStatus.published);
    }
  }

  Future<void> _deleteWithUndo(DraftItem draft) async {
    final removal =
        ref.read(scratchpadProvider.notifier).deleteDraftNow(draft.id);
    if (removal == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted “${removal.draft.title}”'),
        action: SnackBarAction(
          key: const Key('draft-undo-delete'),
          label: 'Undo',
          onPressed: () {
            ref.read(scratchpadProvider.notifier).undoDelete(removal);
          },
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.draftCount});

  final int draftCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final countLabel = draftCount == 1 ? '1 draft' : '$draftCount drafts';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PenningPal',
            key: const Key('drafts-brand'),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: -0.4,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            key: const Key('drafts-count'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.isActive,
    required this.onTap,
    required this.onOpenActions,
    required this.onDelete,
  });

  final DraftItem draft;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onOpenActions;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wordCount = ScratchpadState.countWords(draft.markdownContent);
    final slideCount =
        CarouselDeck.fromMarkdown(draft.markdownContent).totalSlides;
    final preview = DraftItem.previewSnippet(draft.markdownContent);
    final wordsLabel = wordCount == 1 ? '1 word' : '$wordCount words';
    final slidesLabel = slideCount == 1 ? '1 slide' : '$slideCount slides';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Dismissible(
        key: Key('draft-dismiss-${draft.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.delete_outline, color: Colors.white),
            ),
          ),
        ),
        child: Material(
          color: isActive
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.outlineVariant.withValues(alpha: 0.35),
              width: isActive ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            key: Key('draft-tile-${draft.id}'),
            onTap: onTap,
            onLongPress: onOpenActions,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          draft.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DraftStatusBadge(
                        key: Key('draft-status-${draft.id}'),
                        status: draft.status,
                      ),
                      IconButton(
                        key: Key('draft-menu-${draft.id}'),
                        tooltip: 'Draft actions',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_horiz),
                        onPressed: onOpenActions,
                      ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.35,
                        color: colors.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatRelativeTime(draft.updatedAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      _MetaPill(label: wordsLabel),
                      _MetaPill(label: slidesLabel),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact status pill used in the drawer and the scratchpad app bar.
class DraftStatusBadge extends StatelessWidget {
  const DraftStatusBadge({super.key, required this.status});

  final DraftStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          status.displayName,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: status.foreground,
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

enum DraftAction {
  duplicate,
  delete,
  markDraft,
  markReady,
  markPublished,
}

Future<DraftAction?> showDraftActions(
  BuildContext context,
  DraftItem draft,
) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<DraftAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: Key('draft-duplicate-${draft.id}'),
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(DraftAction.duplicate),
            ),
            ListTile(
              key: Key('draft-mark-${draft.id}-draft'),
              title: const Text('Mark as Draft'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(DraftAction.markDraft),
            ),
            ListTile(
              key: Key('draft-mark-${draft.id}-ready'),
              title: const Text('Mark as Ready'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(DraftAction.markReady),
            ),
            ListTile(
              key: Key('draft-mark-${draft.id}-published'),
              title: const Text('Mark as Published'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(DraftAction.markPublished),
            ),
            ListTile(
              key: Key('draft-delete-action-${draft.id}'),
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text('Delete', style: TextStyle(color: colors.error)),
              onTap: () => Navigator.of(sheetContext).pop(DraftAction.delete),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> confirmDraftDelete(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('draft-delete-dialog'),
        title: Text(
          'Delete draft?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '“$title” will be removed from this device. This cannot be undone.',
          style: GoogleFonts.inter(height: 1.4),
        ),
        actions: [
          TextButton(
            key: const Key('draft-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('draft-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
