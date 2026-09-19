import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight.dart' show Node, highlight;

import '../render/code_block_parser.dart';
import '../templates/card_theme_config.dart';

/// Theme-aware fenced-code pane for social cards.
///
/// Highlighting runs on-device via `package:highlight`. Missing or unknown
/// language tags fall back to uncolored JetBrains Mono.
class SyntaxCardBlock extends StatelessWidget {
  const SyntaxCardBlock({
    super.key,
    required this.code,
    required this.theme,
    this.language,
    this.showWindowChrome = false,
    this.chromeTitle,
    this.maxWidth,
  });

  final String code;
  final String? language;
  final CardThemeConfig theme;
  final bool showWindowChrome;
  final String? chromeTitle;
  final double? maxWidth;

  SyntaxCardPalette get palette => SyntaxCardPalette.forTheme(theme);

  /// Fits monospace glyphs into [maxWidth] so long lines stay on-canvas.
  /// Base sizes are 1080px-canvas pixels (30–34px), not mobile points.
  static double fontSizeFor({
    required String code,
    required double maxWidth,
    double minSize = 24,
    double maxSize = 32,
  }) {
    final lines = code.split('\n');
    var longest = 0;
    for (final line in lines) {
      if (line.length > longest) longest = line.length;
    }
    if (longest <= 0 || maxWidth <= 0) return maxSize;
    final fitted = maxWidth / (longest * 0.62);
    return fitted.clamp(minSize, maxSize);
  }

  @override
  Widget build(BuildContext context) {
    final colors = palette;
    final highlightLang = CodeBlockParser.resolveLanguage(language);
    final paneWidth = maxWidth;
    final fontSize = fontSizeFor(
      code: code,
      maxWidth: paneWidth == null ? 800 : (paneWidth - 56).clamp(120, paneWidth),
    );
    final baseStyle = _mono(
      TextStyle(
        color: colors.foreground,
        fontSize: fontSize,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
    );
    final expanded = code.replaceAll('\t', '  ');
    final spans = highlightLang == null
        ? <InlineSpan>[TextSpan(text: expanded)]
        : _highlightedSpans(expanded, highlightLang, colors.tokenTheme);

    final title = (chromeTitle != null && chromeTitle!.trim().isNotEmpty)
        ? chromeTitle!.trim()
        : ((language != null && language!.trim().isNotEmpty)
            ? language!.trim()
            : 'code');

    return DecoratedBox(
      key: const Key('syntax-card-block'),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showWindowChrome)
            _SyntaxWindowChrome(title: title, accent: theme.accentColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Text.rich(
              TextSpan(style: baseStyle, children: spans),
              key: const Key('syntax-card-code'),
              textAlign: TextAlign.left,
              softWrap: true,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}

/// Surfaces and token colors for [SyntaxCardBlock].
class SyntaxCardPalette {
  const SyntaxCardPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.tokenTheme,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Map<String, TextStyle> tokenTheme;

  factory SyntaxCardPalette.forTheme(CardThemeConfig theme) {
    if (theme.variant == CardTemplateVariant.terminal ||
        theme.id == CardPresets.midnightDark.id) {
      return SyntaxCardPalette(
        background: const Color(0xFF0D1117),
        foreground: const Color(0xFFD4D4D4),
        border: const Color(0xFF30363D),
        tokenTheme: atomOneDarkTheme,
      );
    }
    return const SyntaxCardPalette(
      background: Color(0xFFF1F5F9),
      foreground: Color(0xFF1F2937),
      border: Color(0xFFCBD5E1),
      tokenTheme: githubTheme,
    );
  }
}

class _SyntaxWindowChrome extends StatelessWidget {
  const _SyntaxWindowChrome({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161B22),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const _SyntaxTrafficLights(),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _mono(
                    TextStyle(
                      color: accent.withValues(alpha: 0.85),
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 72),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyntaxTrafficLights extends StatelessWidget {
  const _SyntaxTrafficLights();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('terminal-traffic-lights'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _SyntaxDot(color: Color(0xFFFF5F56)),
        SizedBox(width: 10),
        _SyntaxDot(color: Color(0xFFFFBD2E)),
        SizedBox(width: 10),
        _SyntaxDot(color: Color(0xFF27C93F)),
      ],
    );
  }
}

class _SyntaxDot extends StatelessWidget {
  const _SyntaxDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

List<InlineSpan> _highlightedSpans(
  String code,
  String language,
  Map<String, TextStyle> theme,
) {
  try {
    final nodes = highlight.parse(code, language: language).nodes;
    if (nodes == null || nodes.isEmpty) {
      return [TextSpan(text: code)];
    }
    return _convertNodes(nodes, theme);
  } catch (_) {
    return [TextSpan(text: code)];
  }
}

List<TextSpan> _convertNodes(
  List<Node> nodes,
  Map<String, TextStyle> theme,
) {
  final spans = <TextSpan>[];
  var current = spans;
  final stack = <List<TextSpan>>[];

  void traverse(Node node) {
    if (node.value != null) {
      current.add(
        TextSpan(
          text: node.value,
          style: node.className == null ? null : theme[node.className!],
        ),
      );
      return;
    }
    final children = node.children;
    if (children == null || children.isEmpty) return;

    final nested = <TextSpan>[];
    current.add(
      TextSpan(
        children: nested,
        style: node.className == null ? null : theme[node.className!],
      ),
    );
    stack.add(current);
    current = nested;
    for (var i = 0; i < children.length; i++) {
      traverse(children[i]);
      if (i == children.length - 1) {
        current = stack.isEmpty ? spans : stack.removeLast();
      }
    }
  }

  for (final node in nodes) {
    traverse(node);
  }
  return spans;
}

TextStyle _mono(TextStyle base) {
  try {
    return GoogleFonts.jetBrainsMono(textStyle: base);
  } catch (_) {
    return base.copyWith(fontFamily: 'monospace');
  }
}
