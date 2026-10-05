import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/platform_metrics.dart';

/// Compact platform meters docked directly above the formatting toolbar.
///
/// Tapping a badge makes that network the primary limit shown underneath.
class PlatformCounterHud extends StatefulWidget {
  const PlatformCounterHud({
    super.key,
    required this.markdown,
  });

  final String markdown;

  @override
  State<PlatformCounterHud> createState() => _PlatformCounterHudState();
}

class _PlatformCounterHudState extends State<PlatformCounterHud> {
  SocialPlatform _focus = SocialPlatform.linkedIn;

  @override
  Widget build(BuildContext context) {
    final metrics = PlatformMetrics.analyze(widget.markdown);
    final colors = Theme.of(context).colorScheme;
    final focus = metrics.limitFor(_focus);
    final muted = colors.onSurface.withValues(alpha: 0.55);

    return Material(
      key: const Key('platform-counter-hud'),
      color: colors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StatsChip(metrics: metrics, color: muted),
                  const SizedBox(width: 8),
                  for (final platform in SocialPlatform.values) ...[
                    _PlatformBadge(
                      platform: platform,
                      snapshot: metrics.limitFor(platform),
                      selected: platform == _focus,
                      showHookWarning: platform == SocialPlatform.linkedIn &&
                          metrics.fold.hookExceedsFold,
                      onTap: () => setState(() => _focus = platform),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            _FocusMeter(
              platform: _focus,
              snapshot: focus,
              hookWarning: _focus == SocialPlatform.linkedIn &&
                  metrics.fold.hookExceedsFold,
              hookLength: metrics.fold.hookLength,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  const _StatsChip({required this.metrics, required this.color});

  final PlatformMetrics metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final words = metrics.wordCount == 1 ? 'word' : 'words';
    return Center(
      child: Text(
        '${metrics.wordCount} $words · ${metrics.readMinutes} min',
        key: const Key('hud-word-count'),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({
    required this.platform,
    required this.snapshot,
    required this.selected,
    required this.showHookWarning,
    required this.onTap,
  });

  final SocialPlatform platform;
  final PlatformLimitSnapshot snapshot;
  final bool selected;
  final bool showHookWarning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = _toneColor(snapshot.tone);
    final label = _shortLabel(platform);

    return Semantics(
      button: true,
      selected: selected,
      label: '${_fullLabel(platform)} ${snapshot.count} of ${snapshot.limit}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('platform-badge-${platform.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? tone.withValues(alpha: 0.16)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.55),
              border: Border.all(
                color: selected
                    ? tone
                    : colors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? tone : colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniMeter(fraction: snapshot.fraction, color: tone),
                  if (showHookWarning) ...[
                    const SizedBox(width: 6),
                    const _HookWarningDot(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMeter extends StatelessWidget {
  const _MiniMeter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const width = 28.0;
    final fill = fraction.clamp(0, 1).toDouble() * width;
    return SizedBox(
      width: width,
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: fill,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HookWarningDot extends StatelessWidget {
  const _HookWarningDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('linkedin-hook-warning'),
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFD97706),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FocusMeter extends StatelessWidget {
  const _FocusMeter({
    required this.platform,
    required this.snapshot,
    required this.hookWarning,
    required this.hookLength,
  });

  final SocialPlatform platform;
  final PlatformLimitSnapshot snapshot;
  final bool hookWarning;
  final int hookLength;

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(snapshot.tone);
    final colors = Theme.of(context).colorScheme;
    final label =
        '${_fullLabel(platform)}  ${_group(snapshot.count)} / ${_group(snapshot.limit)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                key: Key('platform-focus-${platform.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (hookWarning)
              Text(
                'Hook $hookLength',
                key: const Key('linkedin-hook-count'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            key: Key('platform-progress-${snapshot.tone.name}'),
            value: snapshot.fraction.clamp(0, 1).toDouble(),
            minHeight: 4,
            color: tone,
            backgroundColor: tone.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

String _shortLabel(SocialPlatform platform) {
  switch (platform) {
    case SocialPlatform.linkedIn:
      return 'in';
    case SocialPlatform.x:
      return 'X';
    case SocialPlatform.threads:
      return 'Th';
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

String _group(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
