import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/persistence/draft_storage.dart';
import '../../exporter/models/carousel_deck.dart';
import '../state/draft_presentation.dart';
import '../state/scratchpad_notifier.dart';
import '../state/scratchpad_state.dart';

/// Slide-out workspace for switching, creating, and deleting local drafts.
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
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final drafts = ref.watch(draftListProvider);
    final activeId = ref.watch(scratchpadProvider).activeDraftId;
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? drafts
        : drafts
            .where((draft) {
              return draft.title.toLowerCase().contains(query) ||
                  draft.content.toLowerCase().contains(query);
            })
            .toList();

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
                  'New Post',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('drafts-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
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
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty ? 'No drafts yet' : 'No matching drafts',
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
                          onTap: () {
                            ref
                                .read(scratchpadProvider.notifier)
                                .switchDraft(draft.id);
                            Navigator.of(context).maybePop();
                          },
                          onDelete: () => ref
                              .read(scratchpadProvider.notifier)
                              .deleteDraftById(draft.id),
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
    required this.onDelete,
  });

  final Draft draft;
  final bool isActive;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wordCount = ScratchpadState.countWords(draft.content);
    final slideCount = CarouselDeck.fromMarkdown(draft.content).totalSlides;
    final preview = Draft.previewSnippet(draft.content);
    final wordsLabel = wordCount == 1 ? '1 word' : '$wordCount words';
    final slidesLabel = slideCount == 1 ? '1 slide' : '$slideCount slides';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Dismissible(
        key: Key('draft-dismiss-${draft.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmDraftDelete(context, draft.title),
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: colors.onSurface,
                    ),
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
