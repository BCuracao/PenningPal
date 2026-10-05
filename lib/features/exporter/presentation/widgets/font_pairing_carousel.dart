import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/font_pairing.dart';

/// Horizontal list of curated headline / body pairings.
class FontPairingCarousel extends StatelessWidget {
  const FontPairingCarousel({
    super.key,
    required this.selectedId,
    required this.isProPurchased,
    required this.onSelected,
    this.enabled = true,
  });

  final String? selectedId;
  final bool isProPurchased;
  final ValueChanged<FontPairing> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        key: const Key('font-pairing-carousel'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: FontPairings.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pairing = FontPairings.all[index];
          final locked = pairing.isPro && !isProPurchased;
          final selected = pairing.id == selectedId;
          return _FontPairingChip(
            pairing: pairing,
            selected: selected,
            locked: locked,
            onTap: enabled ? () => onSelected(pairing) : null,
          );
        },
      ),
    );
  }
}

class _FontPairingChip extends StatelessWidget {
  const _FontPairingChip({
    required this.pairing,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final FontPairing pairing;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.55)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('font-pairing-${pairing.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pairing.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.lock_outline,
                      key: Key('font-pairing-lock-${pairing.id}'),
                      size: 14,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ],
                ],
              ),
              Text(
                '${pairing.headerFamily} & ${pairing.bodyFamily}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
