import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/slide_role.dart';

/// Horizontal mini-previews for a carousel deck.
///
/// Tap a thumbnail to preview that slide. Long-press drags it into a new
/// order. Each thumbnail can duplicate or delete its slide, and the trailing
/// button appends a page.
class SlideThumbnailStrip extends StatelessWidget {
  const SlideThumbnailStrip({
    super.key,
    required this.slides,
    required this.activeIndex,
    required this.onSelect,
    required this.onReorder,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAdd,
    this.enabled = true,
  });

  final List<String> slides;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canDelete = slides.length > 1;

    return SizedBox(
      key: const Key('slide-thumbnail-strip'),
      height: 112,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              itemCount: slides.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: child,
                );
              },
              onReorderItem: (oldIndex, newIndex) {
                if (!enabled) return;
                onReorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final active = index == activeIndex;
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('slide-thumb-$index-${slides[index].hashCode}'),
                  index: index,
                  enabled: enabled,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Thumbnail(
                      index: index,
                      label: _snippet(slides[index]),
                      active: active,
                      enabled: enabled,
                      canDelete: canDelete,
                      colors: colors,
                      onSelect: () => onSelect(index),
                      onDuplicate: () => onDuplicate(index),
                      onDelete: () => onDelete(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: _AddSlideButton(enabled: enabled, onPressed: onAdd),
          ),
        ],
      ),
    );
  }

  static String _snippet(String slide) {
    final flat = slide.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return 'Empty';
    if (flat.length <= 48) return flat;
    return '${flat.substring(0, 48)}…';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.index,
    required this.label,
    required this.active,
    required this.enabled,
    required this.canDelete,
    required this.colors,
    required this.onSelect,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final String label;
  final bool active;
  final bool enabled;
  final bool canDelete;
  final ColorScheme colors;
  final VoidCallback onSelect;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final border = active ? colors.primary : colors.outlineVariant;
    return Material(
      color: active
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('slide-thumbnail-$index'),
        onTap: enabled ? onSelect : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: active ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? colors.primary : colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _ActionMenu(
                    index: index,
                    enabled: enabled,
                    canDelete: canDelete,
                    onDuplicate: onDuplicate,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.index,
    required this.enabled,
    required this.canDelete,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final bool enabled;
  final bool canDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('slide-actions-$index'),
      enabled: enabled,
      tooltip: 'Slide actions',
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: const Icon(Icons.more_horiz, size: 18),
      onSelected: (value) {
        if (value == 'duplicate') onDuplicate();
        if (value == 'delete' && canDelete) onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: Key('slide-duplicate-$index'),
          value: 'duplicate',
          child: const Text('Duplicate'),
        ),
        PopupMenuItem<String>(
          key: Key('slide-delete-$index'),
          value: 'delete',
          enabled: canDelete,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _AddSlideButton extends StatelessWidget {
  const _AddSlideButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 84,
      child: OutlinedButton(
        key: const Key('slide-add'),
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: colors.primary),
            const SizedBox(height: 4),
            Text(
              'Add Slide',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Cover | Body | CTA control for the slide currently in preview.
class SlideRoleSelector extends StatelessWidget {
  const SlideRoleSelector({
    super.key,
    required this.role,
    required this.onChanged,
  });

  final SlideRole role;
  final ValueChanged<SlideRole>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SlideRole>(
      key: const Key('slide-role-selector'),
      expandedInsets: EdgeInsets.zero,
      segments: [
        for (final value in SlideRole.values)
          ButtonSegment<SlideRole>(
            value: value,
            label: Text(
              value.label,
              key: Key('slide-role-${value.name}'),
            ),
          ),
      ],
      selected: {role},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null
          ? null
          : (next) {
              if (next.isEmpty) return;
              onChanged!(next.single);
            },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
