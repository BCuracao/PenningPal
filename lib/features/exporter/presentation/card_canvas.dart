import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../templates/card_theme_config.dart';

/// Fixed-size social card. Stateless: every pixel is derived from props.
///
/// Wrapped in a [RepaintBoundary] keyed by [canvasKey] so [CardRasterizer]
/// can snapshot the 1080×1080 or 1080×1920 layout regardless of the preview
/// scale applied by the parent.
class CardCanvas extends StatelessWidget {
  const CardCanvas({
    super.key,
    required this.canvasKey,
    required this.text,
    required this.aspectRatio,
    required this.theme,
    this.author,
    this.isProPurchased = false,
  });

  /// Key attached to the [RepaintBoundary] — not this widget.
  final GlobalKey canvasKey;

  final String text;
  final CardAspectRatio aspectRatio;
  final CardThemeConfig theme;
  final String? author;

  /// Reactive entitlement. When `false`, the watermark is forced on regardless
  /// of [CardThemeConfig.showWatermark] so UI state cannot bypass the gate.
  final bool isProPurchased;

  @override
  Widget build(BuildContext context) {
    final body = text.trim();
    final gatedTheme = theme.enforcedFor(isProPurchased: isProPurchased);
    final decoration = BoxDecoration(
      color: gatedTheme.backgroundColor,
      gradient: gatedTheme.backgroundGradient,
      border: gatedTheme.variant == CardTemplateVariant.plain
          ? Border.all(
              color: gatedTheme.accentColor.withValues(alpha: 0.45),
              width: 3,
            )
          : null,
    );

    return RepaintBoundary(
      key: canvasKey,
      child: SizedBox(
        key: const Key('card-canvas'),
        width: aspectRatio.width,
        height: aspectRatio.height,
        child: DecoratedBox(
          decoration: decoration,
          child: gatedTheme.variant == CardTemplateVariant.terminal
              ? _TerminalCard(
                  theme: gatedTheme,
                  aspectRatio: aspectRatio,
                  text: body,
                  author: author,
                )
              : _PlainCard(
                  theme: gatedTheme,
                  aspectRatio: aspectRatio,
                  text: body,
                  author: author,
                ),
        ),
      ),
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({
    required this.theme,
    required this.aspectRatio,
    required this.text,
    required this.author,
  });

  final CardThemeConfig theme;
  final CardAspectRatio aspectRatio;
  final String text;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final handle = author?.trim();
    final fontSize = CardLayout.fontSizeFor(text, aspectRatio);
    final muted = theme.textColor.withValues(alpha: 0.42);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CardLayout.padding,
        CardLayout.padding * 0.85,
        CardLayout.padding,
        CardLayout.padding * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: CardLayout.headerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (handle != null && handle.isNotEmpty) ? handle : 'Clean Canvas',
                key: const Key('card-brand-slot'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cardFont(
                  fontFamily: theme.fontFamily,
                  color: theme.accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  height: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                text.isEmpty ? 'Start writing…' : text,
                key: const Key('card-body-text'),
                textAlign: TextAlign.center,
                maxLines: aspectRatio.maxLines,
                overflow: TextOverflow.fade,
                style: _cardFont(
                  fontFamily: theme.fontFamily,
                  color: text.isEmpty ? muted : theme.textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          if (theme.showWatermark)
            SizedBox(
              height: CardLayout.footerHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  CardLayout.watermarkLabel,
                  key: const Key('card-watermark'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardFont(
                    fontFamily: theme.fontFamily,
                    color: muted,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({
    required this.theme,
    required this.aspectRatio,
    required this.text,
    required this.author,
  });

  final CardThemeConfig theme;
  final CardAspectRatio aspectRatio;
  final String text;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final fontSize = CardLayout.fontSizeFor(text, aspectRatio);
    final comment = const Color(0xFF6A9955);
    final stringColor = const Color(0xFFCE9178);
    final muted = theme.textColor.withValues(alpha: 0.45);
    final title = (author != null && author!.trim().isNotEmpty)
        ? author!.trim()
        : theme.chromeTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TerminalChrome(title: title, accent: theme.accentColor),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CardLayout.padding,
              48,
              CardLayout.padding,
              32,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text.rich(
                TextSpan(
                  children: _syntaxSpans(
                    text.isEmpty ? '// Start writing…' : text,
                    base: text.isEmpty ? muted : theme.textColor,
                    comment: comment,
                    stringColor: stringColor,
                    accent: theme.accentColor,
                  ),
                ),
                key: const Key('card-body-text'),
                textAlign: TextAlign.left,
                maxLines: aspectRatio.maxLines,
                overflow: TextOverflow.fade,
                style: _cardFont(
                  fontFamily: theme.fontFamily,
                  color: theme.textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        if (theme.showWatermark)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CardLayout.padding,
              0,
              CardLayout.padding,
              CardLayout.padding * 0.6,
            ),
            child: Text(
              CardLayout.watermarkLabel,
              key: const Key('card-watermark'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cardFont(
                fontFamily: theme.fontFamily,
                color: muted,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _TerminalChrome extends StatelessWidget {
  const _TerminalChrome({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2D2D2D),
      child: SizedBox(
        height: 96,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              const _TrafficLights(),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _cardFont(
                    fontFamily: CardThemeConfig.fontJetBrainsMono,
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 84),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('terminal-traffic-lights'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficDot(color: Color(0xFFFF5F56)),
        SizedBox(width: 12),
        _TrafficDot(color: Color(0xFFFFBD2E)),
        SizedBox(width: 12),
        _TrafficDot(color: Color(0xFF27C93F)),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

List<InlineSpan> _syntaxSpans(
  String text, {
  required Color base,
  required Color comment,
  required Color stringColor,
  required Color accent,
}) {
  final lines = text.split('\n');
  final spans = <InlineSpan>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final suffix = i == lines.length - 1 ? '' : '\n';
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/*')) {
      spans.add(TextSpan(
        text: '$line$suffix',
        style: TextStyle(color: comment),
      ));
    } else if (trimmed.startsWith('\$') || trimmed.startsWith('>')) {
      spans.add(TextSpan(
        text: '$line$suffix',
        style: TextStyle(color: accent),
      ));
    } else if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      spans.add(TextSpan(
        text: '$line$suffix',
        style: TextStyle(color: stringColor),
      ));
    } else {
      spans.add(TextSpan(
        text: '$line$suffix',
        style: TextStyle(color: base),
      ));
    }
  }
  return spans;
}

TextStyle _cardFont({
  required String fontFamily,
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  double height = 1.4,
  double? letterSpacing,
}) {
  final base = TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
  );
  try {
    if (fontFamily == CardThemeConfig.fontJetBrainsMono) {
      return GoogleFonts.jetBrainsMono(textStyle: base);
    }
    return GoogleFonts.inter(textStyle: base);
  } catch (_) {
    return base.copyWith(
      fontFamily: fontFamily == CardThemeConfig.fontJetBrainsMono
          ? 'monospace'
          : null,
    );
  }
}
