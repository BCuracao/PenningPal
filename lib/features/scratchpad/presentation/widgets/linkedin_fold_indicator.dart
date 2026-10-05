import 'package:flutter/material.dart';

import '../../state/platform_metrics.dart';

/// Subtle rule at the bottom of the editor for LinkedIn's 210-character fold.
///
/// The status itself lives on the compact HUD dot. This marker does not write
/// into the Markdown buffer and does not add a text block under the draft.
class LinkedInFoldIndicator extends StatelessWidget {
  const LinkedInFoldIndicator({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final fold = PlatformMetrics.analyze(markdown).fold;
    final withinFold = fold.hookLength <= fold.foldThreshold;
    final colors = Theme.of(context).colorScheme;
    final color = withinFold
        ? colors.outlineVariant.withValues(alpha: 0.85)
        : const Color(0xFFD97706).withValues(alpha: 0.9);

    return Semantics(
      key: const Key('linkedin-fold-indicator'),
      label: withinFold
          ? 'LinkedIn see more fold. Opening hook is within '
                '${fold.foldThreshold} characters.'
          : 'LinkedIn see more fold. Opening hook is past '
                '${fold.foldThreshold} characters.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
        child: Container(height: 1, color: color),
      ),
    );
  }
}
