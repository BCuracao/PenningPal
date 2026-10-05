import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/platform_metrics.dart';

/// Single-line platform meter docked above the formatting toolbar.
///
/// The left pill is the active limit (`LinkedIn 120/3000`). Tap it to cycle
/// LinkedIn, X, and Threads. The right side is word count, reading time, and
/// a fold dot: green at or under 210 characters, amber past that.
class PlatformCounterHud extends StatefulWidget {
  const PlatformCounterHud({super.key, required this.markdown});

  final String markdown;

  @override
  State<PlatformCounterHud> createState() => _PlatformCounterHudState();
}

class _PlatformCounterHudState extends State<PlatformCounterHud> {
  SocialPlatform _focus = SocialPlatform.linkedIn;

  void _cyclePlatform() {
    const order = SocialPlatform.values;
    final next = (order.indexOf(_focus) + 1) % order.length;
    setState(() => _focus = order[next]);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = PlatformMetrics.analyze(widget.markdown);
    final focus = metrics.limitFor(_focus);
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurface.withValues(alpha: 0.55);
    final withinFold =
        metrics.fold.hookLength <= PlatformMetrics.linkedInFoldThreshold;
    final words = metrics.wordCount == 1 ? 'word' : 'words';

    return Material(
      key: const Key('platform-counter-hud'),
      color: colors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _LimitPill(
                  platform: _focus,
                  snapshot: focus,
                  onTap: _cyclePlatform,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${metrics.wordCount} $words · ${metrics.readMinutes} min',
                  key: const Key('hud-word-count'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _FoldDot(withinFold: withinFold),
          ],
        ),
      ),
    );
  }
}

class _LimitPill extends StatelessWidget {
  const _LimitPill({
    required this.platform,
    required this.snapshot,
    required this.onTap,
  });

  final SocialPlatform platform;
  final PlatformLimitSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(snapshot.tone);
    final label = _fullLabel(platform);
    final text = '$label ${snapshot.count}/${snapshot.limit}';

    return Semantics(
      button: true,
      selected: true,
      label: '$label ${snapshot.count} of ${snapshot.limit}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('platform-focus-${platform.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: tone.withValues(alpha: 0.12),
              border: Border.all(color: tone.withValues(alpha: 0.85)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldDot extends StatelessWidget {
  const _FoldDot({required this.withinFold});

  final bool withinFold;

  @override
  Widget build(BuildContext context) {
    final color = withinFold
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    return Tooltip(
      message: withinFold
          ? 'Opening hook is within 210 characters'
          : 'Opening hook is past 210 characters',
      child: Semantics(
        label: withinFold
            ? 'LinkedIn fold within 210 characters'
            : 'LinkedIn fold past 210 characters',
        child: Container(
          key: withinFold
              ? const Key('linkedin-fold-dot')
              : const Key('linkedin-hook-warning'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

String _fullLabel(SocialPlatform platform) {
  switch (platform) {
    case SocialPlatform.linkedIn:
      return 'LinkedIn';
    case SocialPlatform.x:
      return 'X';
    case SocialPlatform.threads:
      return 'Threads';
  }
}

Color _toneColor(LimitTone tone) {
  switch (tone) {
    case LimitTone.safe:
      return const Color(0xFF16A34A);
    case LimitTone.caution:
      return const Color(0xFFD97706);
    case LimitTone.overflow:
      return const Color(0xFFDC2626);
  }
}
