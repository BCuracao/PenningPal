import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/slide_role.dart';

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
            label: Text(value.label, key: Key('slide-role-${value.name}')),
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
