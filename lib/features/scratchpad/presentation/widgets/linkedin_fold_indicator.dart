import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/platform_metrics.dart';

/// Status marker for LinkedIn's ~210-character mobile "see more" cutoff.
///
/// Sits under the editor. It reports the fold index and the line-break
/// positions that lead up to it, without writing anything into the draft.
class LinkedInFoldIndicator extends StatelessWidget {
  const LinkedInFoldIndicator({
    super.key,
    required this.markdown,
  });

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final fold = PlatformMetrics.analyze(markdown).fold;
    final colors = Theme.of(context).colorScheme;
    final warning = fold.hookExceedsFold;
    final accent = warning ? const Color(0xFFD97706) : colors.primary;
    final muted = colors.onSurface.withValues(alpha: 0.55);

    final headline = fold.pastFold
        ? 'See more · character ${fold.foldOffset} · line ${fold.foldLine}'
        : 'Above the fold · ${fold.foldOffset}/${fold.foldThreshold}';

    return Material(
      key: const Key('linkedin-fold-indicator'),
      color: colors.surface,
      child: Semantics(
        label: _semantics(fold),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _Rule(color: accent.withValues(alpha: 0.45))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'see more',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: accent,
                      ),
                    ),
                  ),
                  Expanded(child: _Rule(color: accent.withValues(alpha: 0.45))),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                headline,
                key: const Key('linkedin-fold-headline'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: warning ? accent : muted,
                ),
              ),
              Text(
                _breaksLabel(fold),
                key: const Key('linkedin-fold-breaks'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              if (warning)
                Text(
                  'Opening hook is ${fold.hookLength} characters',
                  key: const Key('linkedin-fold-warning'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _breaksLabel(LinkedInFoldSnapshot fold) {
    final offsets = fold.lineBreakOffsets;
    if (offsets.isEmpty) return 'No line breaks yet';
    final shown = offsets.length <= 4
        ? offsets.join(', ')
        : '${offsets.take(4).join(', ')}…';
    final nearest = fold.nearestBreakAtOrBeforeFold;
    final nearestLabel =
        nearest == null ? '' : ' · nearest break at $nearest';
    return 'Line breaks at $shown$nearestLabel';
  }

  static String _semantics(LinkedInFoldSnapshot fold) {
    final breaks = fold.lineBreakOffsets.isEmpty
        ? 'no line breaks'
        : 'line breaks at ${fold.lineBreakOffsets.join(', ')}';
    return 'LinkedIn see more fold at character ${fold.foldOffset}, '
        'line ${fold.foldLine}, $breaks';
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: color);
  }
}
