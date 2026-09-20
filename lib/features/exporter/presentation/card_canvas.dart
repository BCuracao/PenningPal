import 'dart:io';
import 'dart:ui' as ui;

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
    this.authorHandle,
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
  final String? authorHandle;

  /// Raw purchase flag used by callers. Watermark enforcement also honors
  /// the demo bypass switch so recordings can strip the mark without
  /// flipping visual lock badges.
  final bool isProPurchased;

  /// Zero-based index of this slide when rendering a carousel.
  final int? currentSlideIndex;

  /// Total slides in the deck. A badge is shown when this is greater than 1.
  final int? totalSlides;

  @override
  Widget build(BuildContext context) {
    final body = text.trim();
    final gatedTheme = theme.enforcedFor(isProPurchased: isProPurchased);
    final displayTheme = gatedTheme.hasCustomBackground
        ? gatedTheme.copyWith(textColor: gatedTheme.photoAwareTextColor)
        : gatedTheme;
    final border = displayTheme.resolvedBorder;
    final hasPhoto = displayTheme.hasCustomBackground;

    final showPagination = totalSlides != null && totalSlides! > 1;
    final slideIndex = currentSlideIndex ?? 0;

    return RepaintBoundary(
      key: canvasKey,
      child: SizedBox(
        key: const Key('card-canvas'),
        width: aspectRatio.width,
        height: aspectRatio.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: displayTheme.backgroundColor,
                  gradient: hasPhoto ? null : displayTheme.backgroundGradient,
                ),
              ),
            ),
            if (hasPhoto)
              Positioned.fill(
                child: _PhotoBackdrop(
                  path: displayTheme.customBackgroundImagePath!,
                  blurSigma: displayTheme.resolvedBlurSigma,
                  scrimColor: displayTheme.photoScrimColor,
                  cacheLongEdge: _photoDecodeLongEdge(aspectRatio),
                ),
              )
            else
              for (final overlay in displayTheme.overlayGradients)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: overlay),
                  ),
                ),
            Positioned.fill(
              child: displayTheme.variant == CardTemplateVariant.terminal
                  ? _TerminalCard(
                      theme: displayTheme,
                      text: body,
                      author: author,
                      authorHandle: authorHandle,
                    )
                  : _PlainCard(
                      theme: displayTheme,
                      text: body,
                      author: author,
                      authorHandle: authorHandle,
                    ),
            ),
            if (border != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: border),
                  ),
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
                  foreground: displayTheme.textColor,
                  fontFamily: displayTheme.fontFamily,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

int _photoDecodeLongEdge(CardAspectRatio ratio) {
  final long = ratio.width > ratio.height ? ratio.width : ratio.height;
  return (long * 3).round();
}

/// Full-bleed blurred photo with a contrast scrim so type stays legible
/// at 1080×1080 and 1080×1920, including high-DPI (`pixelRatio: 3`) export.
class _PhotoBackdrop extends StatelessWidget {
  const _PhotoBackdrop({
    required this.path,
    required this.blurSigma,
    required this.scrimColor,
    required this.cacheLongEdge,
  });

  final String path;
  final double blurSigma;
  final Color scrimColor;
  final int cacheLongEdge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            key: const Key('card-photo-backdrop'),
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.clamp,
            ),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              cacheWidth: cacheLongEdge,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
        ColoredBox(
          key: const Key('card-photo-scrim'),
          color: scrimColor,
        ),
      ],
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({
    required this.theme,
    required this.text,
    required this.author,
    required this.authorHandle,
  });

  final CardThemeConfig theme;
  final String text;
  final String? author;
  final String? authorHandle;

  @override
  Widget build(BuildContext context) {
    final identity = resolveCardAuthor(author, authorHandle);
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
              child: _AuthorHeader(
                name: identity.name,
                handle: identity.handle,
                theme: theme,
                muted: muted,
              ),
            ),
          ),
          Expanded(
            child: _SlideBody(
              text: text,
              theme: theme,
              showCodeChrome: false,
              chromeTitle: identity.handle ?? identity.name,
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
                    fontSize: CardLayout.watermarkSize,
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
    required this.authorHandle,
  });

  final CardThemeConfig theme;
  final String text;
  final String? author;
  final String? authorHandle;

  @override
  Widget build(BuildContext context) {
    final muted = theme.textColor.withValues(alpha: 0.45);
    final identity = resolveCardAuthor(author, authorHandle);
    final title = identity.handle ?? identity.name ?? theme.chromeTitle;
    final parsed = const CodeBlockParser().parse(text);
    final useCodeWindow = parsed.hasCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!useCodeWindow)
          _TerminalChrome(title: title, accent: theme.accentColor),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              CardLayout.padding,
              useCodeWindow ? CardLayout.verticalPadding : 32,
              CardLayout.padding,
              24,
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
              CardLayout.verticalPadding,
            ),
            child: Text(
              CardLayout.watermarkLabel,
              key: const Key('card-watermark'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cardTypeStyle(
                fontFamily: theme.fontFamily,
                color: muted,
                fontSize: CardLayout.watermarkSize,
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
                    fontSize: CardLayout.authorNameSize,
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
      return Center(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Start writing…',
            key: const Key('card-body-text'),
            textAlign: TextAlign.left,
            style: cardTypeStyle(
              fontFamily: theme.fontFamily,
              color: emptyColor,
              fontSize: CardMarkdownStyles.bodySize * scale,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
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

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
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

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.name,
    required this.handle,
    required this.theme,
    required this.muted,
  });

  final String? name;
  final String? handle;
  final CardThemeConfig theme;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    final hasHandle = handle != null && handle!.isNotEmpty;

    return Column(
      key: const Key('card-brand-slot'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasName)
          Text(
            name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cardTypeStyle(
              fontFamily: theme.fontFamily,
              color: theme.textColor,
              fontSize: CardLayout.authorNameSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        if (hasHandle)
          Padding(
            padding: EdgeInsets.only(top: hasName ? 4 : 0),
            child: Text(
              handle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cardTypeStyle(
                fontFamily: theme.fontFamily,
                color: muted,
                fontSize: CardLayout.authorHandleSize,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Splits the legacy single [author] string plus optional [authorHandle]
/// into a name / handle pair for the canvas header.
({String? name, String? handle}) resolveCardAuthor(
  String? author,
  String? authorHandle,
) {
  final rawName = author?.trim();
  final rawHandle = authorHandle?.trim();

  String? name;
  String? handle;

  if (rawHandle != null && rawHandle.isNotEmpty) {
    handle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';
  }

  if (rawName != null && rawName.isNotEmpty) {
    if (rawName.startsWith('@')) {
      handle ??= rawName;
    } else {
      name = rawName;
    }
  }

  if (name == null && handle == null) {
    name = 'PenningPal';
  }

  return (name: name, handle: handle);
}
