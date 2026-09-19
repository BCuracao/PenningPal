import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../templates/card_theme_config.dart';

/// Publication-grade markdown body for a social card.
///
/// Syntax markers (`#`, `**`, `*`, `>`) are parsed into widgets and never
/// painted. Code fences are expected to be stripped by [CodeBlockParser]
/// before this widget sees the string.
class MarkdownCardContent extends StatelessWidget {
  const MarkdownCardContent({
    super.key,
    required this.content,
    required this.theme,
    required this.fontScale,
    required this.fontFamily,
  });

  final String content;
  final CardThemeConfig theme;
  final double fontScale;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final styles = CardMarkdownStyles.from(
      theme: theme,
      fontScale: fontScale,
      fontFamily: fontFamily,
    );
    final blocks = _parseCardMarkdown(content);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return DefaultTextStyle(
      style: styles.paragraph,
      child: Column(
        key: const Key('markdown-card-content'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == blocks.length - 1 ? 0 : _gapAfter(blocks[i]),
              ),
              child: blocks[i].build(styles),
            ),
        ],
      ),
    );
  }

  static double _gapAfter(_CardMdBlock block) {
    if (block is _HeadingBlock) {
      return switch (block.level) {
        1 => 28,
        2 => 22,
        _ => 18,
      };
    }
    if (block is _QuoteBlock) return 28;
    if (block is _ListBlock) return 24;
    return 26;
  }
}

/// Type scale for rendered card markdown. Sizes are 1080px-canvas pixels
/// multiplied by [fontScale] — not mobile/desktop points.
class CardMarkdownStyles {
  static const double h1Size = 78;
  static const double h2Size = 60;
  static const double h3Size = 48;
  static const double bodySize = 38;
  static const double quoteSize = 42;
  static const double codeSize = 32;
  static const double quoteBorderWidth = 6;
  static const double quotePadding = 28;
  static const double listItemGap = 18;
  static const double bulletColumnWidth = 48;

  const CardMarkdownStyles({
    required this.h1,
    required this.h2,
    required this.h3,
    required this.paragraph,
    required this.strong,
    required this.emphasis,
    required this.quote,
    required this.listItem,
    required this.bullet,
    required this.inlineCode,
    required this.inlineCodeBackground,
    required this.accentColor,
  });

  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle paragraph;
  final TextStyle strong;
  final TextStyle emphasis;
  final TextStyle quote;
  final TextStyle listItem;
  final TextStyle bullet;
  final TextStyle inlineCode;
  final Color inlineCodeBackground;
  final Color accentColor;

  factory CardMarkdownStyles.from({
    required CardThemeConfig theme,
    required double fontScale,
    required String fontFamily,
  }) {
    final scale = fontScale <= 0 ? 1.0 : fontScale;
    final text = theme.textColor;
    final paragraph = cardTypeStyle(
      fontFamily: fontFamily,
      color: text,
      fontSize: bodySize * scale,
      fontWeight: FontWeight.w400,
      height: 1.55,
    );
    return CardMarkdownStyles(
      h1: cardTypeStyle(
        fontFamily: fontFamily,
        color: text,
        fontSize: h1Size * scale,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.8,
      ),
      h2: cardTypeStyle(
        fontFamily: fontFamily,
        color: text,
        fontSize: h2Size * scale,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.5,
      ),
      h3: cardTypeStyle(
        fontFamily: fontFamily,
        color: text,
        fontSize: h3Size * scale,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      paragraph: paragraph,
      strong: paragraph.copyWith(
        fontWeight: FontWeight.w700,
        color: text,
      ),
      emphasis: paragraph.copyWith(fontStyle: FontStyle.italic),
      quote: cardTypeStyle(
        fontFamily: fontFamily,
        color: text.withValues(alpha: 0.78),
        fontSize: quoteSize * scale,
        fontWeight: FontWeight.w400,
        height: 1.45,
        fontStyle: FontStyle.italic,
      ),
      listItem: paragraph,
      bullet: paragraph.copyWith(fontWeight: FontWeight.w600, height: 1.55),
      inlineCode: cardTypeStyle(
        fontFamily: CardThemeConfig.fontJetBrainsMono,
        color: text,
        fontSize: codeSize * scale,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      inlineCodeBackground: text.withValues(alpha: 0.08),
      accentColor: theme.accentColor,
    );
  }
}

List<_CardMdBlock> _parseCardMarkdown(String markdown) {
  final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.trim().isEmpty) return const [];
  return _parseBlocks(normalized);
}

sealed class _CardMdBlock {
  const _CardMdBlock();

  Widget build(CardMarkdownStyles styles);
}

final class _HeadingBlock extends _CardMdBlock {
  const _HeadingBlock(this.level, this.text);

  final int level;
  final String text;

  @override
  Widget build(CardMarkdownStyles styles) {
    final style = switch (level) {
      1 => styles.h1,
      2 => styles.h2,
      _ => styles.h3,
    };
    return Text.rich(
      TextSpan(style: style, children: _inlineSpans(text, styles)),
      textAlign: TextAlign.left,
    );
  }
}

final class _ParagraphBlock extends _CardMdBlock {
  const _ParagraphBlock(this.lines);

  final List<String> lines;

  @override
  Widget build(CardMarkdownStyles styles) {
    final joined = lines.join('\n');
    return Text.rich(
      TextSpan(
        style: styles.paragraph,
        children: _inlineSpans(joined, styles),
      ),
      textAlign: TextAlign.left,
    );
  }
}

final class _QuoteBlock extends _CardMdBlock {
  const _QuoteBlock(this.lines);

  final List<String> lines;

  @override
  Widget build(CardMarkdownStyles styles) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: styles.accentColor,
            width: CardMarkdownStyles.quoteBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: CardMarkdownStyles.quotePadding,
          top: 4,
          bottom: 4,
        ),
        child: Text.rich(
          TextSpan(
            style: styles.quote,
            children: _inlineSpans(lines.join('\n'), styles),
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}

final class _ListBlock extends _CardMdBlock {
  const _ListBlock(this.items);

  final List<String> items;

  @override
  Widget build(CardMarkdownStyles styles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1
                  ? 0
                  : CardMarkdownStyles.listItemGap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: CardMarkdownStyles.bulletColumnWidth,
                  child: Text('•', style: styles.bullet),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: styles.listItem,
                      children: _inlineSpans(items[i], styles),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

List<_CardMdBlock> _parseBlocks(String markdown) {
  final lines = markdown.split('\n');
  final blocks = <_CardMdBlock>[];
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    final header = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (header != null) {
      final level = header.group(1)!.length;
      final body = header.group(2)!.trim();
      blocks.add(_HeadingBlock(level, body));
      i++;
      continue;
    }

    if (_isQuote(line)) {
      final quoteLines = <String>[];
      while (i < lines.length && _isQuote(lines[i])) {
        quoteLines.add(_quoteBody(lines[i]));
        i++;
      }
      blocks.add(_QuoteBlock(quoteLines));
      continue;
    }

    if (_isListItem(line)) {
      final items = <String>[];
      while (i < lines.length && _isListItem(lines[i])) {
        items.add(_listItemBody(lines[i]));
        i++;
      }
      blocks.add(_ListBlock(items));
      continue;
    }

    final paraLines = <String>[];
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_isBlockStart(lines[i])) {
      paraLines.add(lines[i]);
      i++;
    }
    if (paraLines.isNotEmpty) {
      blocks.add(_ParagraphBlock(paraLines));
    }
  }

  return blocks;
}

bool _isBlockStart(String line) {
  if (RegExp(r'^(#{1,3})\s+').hasMatch(line)) return true;
  if (_isQuote(line)) return true;
  if (_isListItem(line)) return true;
  return false;
}

bool _isQuote(String line) => line == '>' || line.startsWith('> ');

String _quoteBody(String line) {
  if (line == '>') return '';
  return line.substring(2);
}

bool _isListItem(String line) => RegExp(r'^(\s*)[-*] ').hasMatch(line);

String _listItemBody(String line) {
  return RegExp(r'^(\s*)[-*] (.*)$').firstMatch(line)!.group(2)!;
}

List<InlineSpan> _inlineSpans(String source, CardMarkdownStyles styles) {
  return _InlineParser(source, styles).parse();
}

class _InlineParser {
  _InlineParser(this.source, this.styles);

  final String source;
  final CardMarkdownStyles styles;
  int pos = 0;

  List<InlineSpan> parse() => _parse();

  List<InlineSpan> _parse({String? closer}) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    while (pos < source.length) {
      if (closer != null && _at(closer)) {
        break;
      }
      if (_tryCode(spans, flush)) {
        continue;
      }
      if (_tryWrap('***', spans, flush, closer, (inner) {
        return TextSpan(
          style: styles.strong.copyWith(fontStyle: FontStyle.italic),
          children: inner,
        );
      })) {
        continue;
      }
      if (_tryWrap('___', spans, flush, closer, (inner) {
        return TextSpan(
          style: styles.strong.copyWith(fontStyle: FontStyle.italic),
          children: inner,
        );
      })) {
        continue;
      }
      if (_tryWrap('**', spans, flush, closer, (inner) {
        return TextSpan(style: styles.strong, children: inner);
      })) {
        continue;
      }
      if (_tryWrap('__', spans, flush, closer, (inner) {
        return TextSpan(style: styles.strong, children: inner);
      })) {
        continue;
      }
      if (_tryWrap('*', spans, flush, closer, (inner) {
        return TextSpan(style: styles.emphasis, children: inner);
      })) {
        continue;
      }
      if (_tryWrap('_', spans, flush, closer, (inner) {
        return TextSpan(style: styles.emphasis, children: inner);
      })) {
        continue;
      }
      buffer.write(_takeRune());
    }

    flush();
    return spans;
  }

  bool _tryCode(List<InlineSpan> spans, void Function() flush) {
    if (!_at('`')) return false;
    final saved = pos;
    pos += 1;
    final close = source.indexOf('`', pos);
    if (close == -1) {
      pos = saved;
      return false;
    }
    final inner = source.substring(pos, close);
    pos = close + 1;
    flush();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: styles.inlineCodeBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(inner, style: styles.inlineCode),
          ),
        ),
      ),
    );
    return true;
  }

  bool _tryWrap(
    String delim,
    List<InlineSpan> spans,
    void Function() flush,
    String? closer,
    InlineSpan Function(List<InlineSpan> inner) wrap,
  ) {
    if (!_at(delim)) return false;
    if (closer != null && delim == closer) return false;
    if (delim == '*' && _at('**')) return false;
    if (delim == '**' && _at('***')) return false;
    if (delim == '_' && _at('__')) return false;
    if (delim == '__' && _at('___')) return false;
    if (delim.startsWith('_') && pos > 0 && _isLatinAlphanumericAt(pos - 1)) {
      return false;
    }

    final saved = pos;
    pos += delim.length;
    final inner = _parse(closer: delim);
    if (pos < source.length && _at(delim)) {
      pos += delim.length;
      flush();
      spans.add(wrap(inner));
      return true;
    }

    pos = saved;
    return false;
  }

  bool _at(String token) => source.startsWith(token, pos);

  bool _isLatinAlphanumericAt(int index) {
    final unit = source.codeUnitAt(index);
    return (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        (unit >= 0x30 && unit <= 0x39);
  }

  String _takeRune() {
    final rune = _codePointAt(pos);
    pos += rune > 0xFFFF ? 2 : 1;
    return String.fromCharCodes([rune]);
  }

  int _codePointAt(int index) {
    final unit = source.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < source.length) {
      final next = source.codeUnitAt(index + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        return 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00);
      }
    }
    return unit;
  }
}

TextStyle cardTypeStyle({
  required String fontFamily,
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  double height = 1.4,
  double? letterSpacing,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
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
