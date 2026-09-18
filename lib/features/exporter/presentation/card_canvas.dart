import 'package:flutter/material.dart';

import '../models/carousel_deck.dart';
import '../render/code_block_parser.dart';
import '../templates/card_theme_config.dart';
import 'markdown_card_content.dart';
import 'syntax_card_block.dart';

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
    this.currentSlideIndex,
    this.totalSlides,
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

  /// Zero-based index of this slide when rendering a carousel.
  final int? currentSlideIndex;

  /// Total slides in the deck. A badge is shown when this is greater than 1.
  final int? totalSlides;

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

    final showPagination = totalSlides != null && totalSlides! > 1;
    final slideIndex = currentSlideIndex ?? 0;

    return RepaintBoundary(
      key: canvasKey,
      child: SizedBox(
        key: const Key('card-canvas'),
        width: aspectRatio.width,
        height: aspectRatio.height,
        child: DecoratedBox(
          decoration: decoration,
          child: Stack(
            children: [
              Positioned.fill(
                child: gatedTheme.variant == CardTemplateVariant.terminal
                    ? _TerminalCard(
                        theme: gatedTheme,
                        text: body,
                        author: author,
                      )
                    : _PlainCard(
                        theme: gatedTheme,
                        text: body,
                        author: author,
                      ),
              ),
              if (showPagination)
                Positioned(
                  top: CardLayout.verticalPadding + 16,
                  right: CardLayout.padding * 0.55,
                  child: _PaginationBadge(
                    label: CarouselDeck.formatPagination(
                      slideIndex,
                      totalSlides!,
                    ),
                    foreground: gatedTheme.textColor,
                    fontFamily: gatedTheme.fontFamily,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({
    required this.theme,
    required this.text,
    required this.author,
  });

  final CardThemeConfig theme;
  final String text;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final handle = author?.trim();
    final muted = theme.textColor.withValues(alpha: 0.42);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CardLayout.padding,
        CardLayout.verticalPadding,
        CardLayout.padding,
        CardLayout.verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: CardLayout.headerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (handle != null && handle.isNotEmpty) ? handle : 'PenningPal',
                key: const Key('card-brand-slot'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cardTypeStyle(
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
            child: _SlideBody(
              text: text,
              theme: theme,
              showCodeChrome: false,
              chromeTitle: handle,
              emptyColor: muted,
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
                  style: cardTypeStyle(
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
    required this.text,
    required this.author,
  });

  final CardThemeConfig theme;
  final String text;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final muted = theme.textColor.withValues(alpha: 0.45);
    final title = (author != null && author!.trim().isNotEmpty)
        ? author!.trim()
        : theme.chromeTitle;
    final parsed = const CodeBlockParser().parse(text);
    final useCodeWindow = parsed.hasCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!useCodeWindow)
          _TerminalChrome(title: title, accent: theme.accentColor),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CardLayout.padding,
              48,
              CardLayout.padding,
              32,
            ),
            child: _SlideBody(
              text: text,
              theme: theme,
              showCodeChrome: useCodeWindow,
              chromeTitle: title,
              emptyColor: muted,
              parsed: parsed,
            ),
          ),
        ),
        if (theme.showWatermark)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CardLayout.padding,
              0,
              CardLayout.padding,
              CardLayout.verticalPadding * 0.6,
            ),
            child: Text(
              CardLayout.watermarkLabel,
              key: const Key('card-watermark'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cardTypeStyle(
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
                  style: cardTypeStyle(
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

class _PaginationBadge extends StatelessWidget {
  const _PaginationBadge({
    required this.label,
    required this.foreground,
    required this.fontFamily,
  });

  final String label;
  final Color foreground;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          label,
          key: const Key('card-pagination-badge'),
          maxLines: 1,
          style: cardTypeStyle(
            fontFamily: fontFamily,
            color: foreground.withValues(alpha: 0.78),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Prose via [MarkdownCardContent], fenced code via [SyntaxCardBlock].
/// Typography scales from the full slide length; FittedBox is the clip guard.
class _SlideBody extends StatelessWidget {
  const _SlideBody({
    required this.text,
    required this.theme,
    required this.showCodeChrome,
    required this.emptyColor,
    this.chromeTitle,
    this.parsed,
  });

  final String text;
  final CardThemeConfig theme;
  final bool showCodeChrome;
  final String? chromeTitle;
  final Color emptyColor;
  final ParsedCardContent? parsed;

  @override
  Widget build(BuildContext context) {
    final scale = CardLayout.fontScaleFor(text);
    final segments = parsed ?? const CodeBlockParser().parse(text);

    if (text.trim().isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Start writing…',
          key: const Key('card-body-text'),
          textAlign: TextAlign.left,
          style: cardTypeStyle(
            fontFamily: theme.fontFamily,
            color: emptyColor,
            fontSize: 22 * scale,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        if (segments.isEmpty) {
          children.add(
            MarkdownCardContent(
              content: text,
              theme: theme,
              fontScale: scale,
              fontFamily: theme.fontFamily,
            ),
          );
        } else {
          for (var i = 0; i < segments.segments.length; i++) {
            final segment = segments.segments[i];
            final isLast = i == segments.segments.length - 1;
            if (segment is ProseSegment) {
              children.add(
                Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
                  child: MarkdownCardContent(
                    content: segment.text,
                    theme: theme,
                    fontScale: scale,
                    fontFamily: theme.fontFamily,
                  ),
                ),
              );
            } else if (segment is CodeBlockSegment) {
              children.add(
                Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
                  child: SyntaxCardBlock(
                    code: segment.code,
                    language: segment.language,
                    theme: theme,
                    showWindowChrome: showCodeChrome,
                    chromeTitle: chromeTitle ?? segment.language,
                    maxWidth: constraints.maxWidth,
                  ),
                ),
              );
            }
          }
        }

        return Align(
          alignment: Alignment.topLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  key: const Key('card-body-text'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
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
