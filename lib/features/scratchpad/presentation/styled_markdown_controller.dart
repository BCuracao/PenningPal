import 'package:flutter/material.dart';

/// Live-styled markdown buffer. The underlying [text] stays raw markdown;
/// only the painted [TextSpan] tree applies visual emphasis.
class StyledMarkdownEditingController extends TextEditingController {
  StyledMarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final colors = Theme.of(context).colorScheme;
    if (text.isEmpty) {
      return TextSpan(style: base, text: '');
    }

    final children = MarkdownTextStyler.spansFor(
      text: text,
      base: base,
      colors: colors,
    );

    if (withComposing && value.isComposingRangeValid) {
      return TextSpan(
        style: base,
        children: _applyComposingUnderline(children, base),
      );
    }

    return TextSpan(style: base, children: children);
  }

  List<InlineSpan> _applyComposingUnderline(
    List<TextSpan> children,
    TextStyle base,
  ) {
    final composing = value.composing;
    final flattened = <TextSpan>[];
    for (final span in children) {
      flattened.addAll(_splitSpan(span, base));
    }

    final out = <InlineSpan>[];
    var cursor = 0;
    for (final span in flattened) {
      final piece = span.text ?? '';
      if (piece.isEmpty) continue;
      final start = cursor;
      final end = cursor + piece.length;
      cursor = end;

      if (end <= composing.start || start >= composing.end) {
        out.add(span);
        continue;
      }

      if (start < composing.start) {
        out.add(TextSpan(
          text: piece.substring(0, composing.start - start),
          style: span.style,
        ));
      }
      final composeFrom = composing.start > start ? composing.start - start : 0;
      final composeTo =
          composing.end < end ? composing.end - start : piece.length;
      out.add(TextSpan(
        text: piece.substring(composeFrom, composeTo),
        style: (span.style ?? base).merge(
          const TextStyle(decoration: TextDecoration.underline),
        ),
      ));
      if (end > composing.end) {
        out.add(TextSpan(
          text: piece.substring(composing.end - start),
          style: span.style,
        ));
      }
    }
    return out;
  }

  List<TextSpan> _splitSpan(TextSpan span, TextStyle base) {
    if (span.children == null || span.children!.isEmpty) {
      return [
        TextSpan(text: span.text ?? '', style: base.merge(span.style)),
      ];
    }
    final out = <TextSpan>[];
    for (final child in span.children!) {
      if (child is TextSpan) {
        out.addAll(_splitSpan(child, base.merge(span.style)));
      }
    }
    return out;
  }
}

/// Builds a 1:1 [TextSpan] tree for a markdown buffer (tokens stay visible).
class MarkdownTextStyler {
  MarkdownTextStyler._();

  static const double heading1Size = 24;
  static const double heading2Size = 20;
  static const double heading3Size = 18;
  static const double markerOpacity = 0.35;

  static List<TextSpan> spansFor({
    required String text,
    required TextStyle base,
    required ColorScheme colors,
  }) {
    return _MarkdownSpanParser(text, base, colors).parse();
  }

  static TextSpan build({
    required String text,
    required TextStyle style,
    required ColorScheme colors,
  }) {
    if (text.isEmpty) return TextSpan(style: style, text: '');
    return TextSpan(
      style: style,
      children: spansFor(text: text, base: style, colors: colors),
    );
  }
}

class _MarkdownSpanParser {
  _MarkdownSpanParser(this.source, this.base, this.colors)
      :         markerStyle = base.copyWith(
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          fontSize: base.fontSize,
          height: base.height,
          color: (base.color ?? colors.onSurface).withValues(
            alpha: MarkdownTextStyler.markerOpacity,
          ),
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        ),
        dividerStyle = base.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: colors.outline,
        ),
        h1Style = base.copyWith(
          fontSize: MarkdownTextStyler.heading1Size,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h2Style = base.copyWith(
          fontSize: MarkdownTextStyler.heading2Size,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        h3Style = base.copyWith(
          fontSize: MarkdownTextStyler.heading3Size,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        quoteStyle = base.copyWith(
          fontStyle: FontStyle.italic,
          color: (base.color ?? colors.onSurface).withValues(alpha: 0.65),
        ),
        inlineCodeStyle = base.copyWith(
          fontFamily: 'monospace',
          fontSize: (base.fontSize ?? 18) * 0.92,
          backgroundColor: colors.primary.withValues(alpha: 0.10),
          color: colors.onSurface,
        ),
        codeBlockStyle = base.copyWith(
          fontFamily: 'monospace',
          fontSize: (base.fontSize ?? 18) * 0.9,
          height: 1.45,
          backgroundColor: colors.primary.withValues(alpha: 0.08),
          color: colors.onSurface,
        );

  final String source;
  final TextStyle base;
  final ColorScheme colors;
  final TextStyle markerStyle;
  final TextStyle dividerStyle;
  final TextStyle h1Style;
  final TextStyle h2Style;
  final TextStyle h3Style;
  final TextStyle quoteStyle;
  final TextStyle inlineCodeStyle;
  final TextStyle codeBlockStyle;

  int pos = 0;

  List<TextSpan> parse() {
    final spans = <TextSpan>[];
    while (pos < source.length) {
      final lineStart = pos;
      final nl = source.indexOf('\n', pos);
      final lineEnd = nl == -1 ? source.length : nl;
      final line = source.substring(lineStart, lineEnd);

      if (_isFenceLine(line)) {
        spans.addAll(_consumeFence(lineStart, lineEnd, nl));
        continue;
      }

      pos = lineEnd;
      spans.addAll(_parseBlockLine(line));
      if (nl != -1) {
        spans.add(TextSpan(text: '\n', style: base));
        pos = nl + 1;
      }
    }
    assert(() {
      final rebuilt = StringBuffer();
      for (final span in spans) {
        rebuilt.write(span.toPlainText());
      }
      return rebuilt.toString() == source;
    }(), 'Styled markdown spans must preserve the raw buffer');
    return spans;
  }

  List<TextSpan> _consumeFence(int lineStart, int lineEnd, int nl) {
    final spans = <TextSpan>[];
    final openLine = source.substring(lineStart, lineEnd);
    spans.add(TextSpan(text: openLine, style: markerStyle));
    if (nl == -1) {
      pos = source.length;
      return spans;
    }
    spans.add(TextSpan(text: '\n', style: markerStyle));
    pos = nl + 1;

    final closeAt = _findClosingFence(pos);
    if (closeAt == null) {
      final body = source.substring(pos);
      if (body.isNotEmpty) {
        spans.add(TextSpan(text: body, style: codeBlockStyle));
      }
      pos = source.length;
      return spans;
    }

    final body = source.substring(pos, closeAt);
    if (body.isNotEmpty) {
      spans.add(TextSpan(text: body, style: codeBlockStyle));
    }
    pos = closeAt;
    final closeNl = source.indexOf('\n', pos);
    final closeEnd = closeNl == -1 ? source.length : closeNl;
    spans.add(TextSpan(
      text: source.substring(pos, closeEnd),
      style: markerStyle,
    ));
    pos = closeEnd;
    if (closeNl != -1) {
      spans.add(TextSpan(text: '\n', style: markerStyle));
      pos = closeNl + 1;
    }
    return spans;
  }

  int? _findClosingFence(int from) {
    var i = from;
    while (i <= source.length) {
      final nl = source.indexOf('\n', i);
      final end = nl == -1 ? source.length : nl;
      final line = source.substring(i, end);
      if (_isFenceLine(line)) return i;
      if (nl == -1) return null;
      i = nl + 1;
    }
    return null;
  }

  bool _isFenceLine(String line) => RegExp(r'^ {0,3}```').hasMatch(line);

  List<TextSpan> _parseBlockLine(String line) {
    if (_isThematicBreak(line)) {
      return [
        TextSpan(
          text: line,
          style: dividerStyle.copyWith(
            letterSpacing: 8,
            decoration: TextDecoration.lineThrough,
            decorationColor: colors.outline.withValues(alpha: 0.75),
            color: colors.outline.withValues(alpha: 0.4),
          ),
        ),
      ];
    }

    final heading = RegExp(r'^(#{1,3})(\s*)').firstMatch(line);
    if (heading != null) {
      final hashes = heading.group(1)!;
      final space = heading.group(2)!;
      final rest = line.substring(heading.group(0)!.length);
      final headingStyle = switch (hashes.length) {
        1 => h1Style,
        2 => h2Style,
        _ => h3Style,
      };
      return [
        TextSpan(text: hashes, style: markerStyle),
        if (space.isNotEmpty) TextSpan(text: space, style: markerStyle),
        ..._parseInline(rest, headingStyle),
      ];
    }

    final quote = RegExp(r'^(>[ \t]?)').firstMatch(line);
    if (quote != null) {
      final rest = line.substring(quote.group(0)!.length);
      return [
        TextSpan(text: quote.group(0)!, style: markerStyle),
        ..._parseInline(rest, quoteStyle),
      ];
    }

    final bullet = RegExp(r'^([ \t]*)([-*+])([ \t]+)').firstMatch(line);
    if (bullet != null) {
      final rest = line.substring(bullet.group(0)!.length);
      return [
        if (bullet.group(1)!.isNotEmpty)
          TextSpan(text: bullet.group(1)!, style: base),
        TextSpan(text: bullet.group(2)! + bullet.group(3)!, style: markerStyle),
        ..._parseInline(rest, base),
      ];
    }

    return _parseInline(line, base);
  }

  bool _isThematicBreak(String line) {
    return RegExp(r'^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$').hasMatch(line);
  }

  List<TextSpan> _parseInline(String line, TextStyle style) {
    return _InlineSpanParser(
      line,
      style: style,
      markerStyle: markerStyle,
      inlineCodeStyle: inlineCodeStyle,
    ).parse();
  }
}

class _InlineSpanParser {
  _InlineSpanParser(
    this.source, {
    required this.style,
    required this.markerStyle,
    required this.inlineCodeStyle,
  });

  final String source;
  final TextStyle style;
  final TextStyle markerStyle;
  final TextStyle inlineCodeStyle;
  int pos = 0;

  List<TextSpan> parse() => _parse(style, null);

  List<TextSpan> _parse(TextStyle current, String? closer) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: current));
      buffer.clear();
    }

    while (pos < source.length) {
      if (closer != null && _at(closer) && !_partialCloser(closer)) {
        break;
      }
      if (_tryCode(spans, flush, closer)) continue;
      if (_tryWrap(spans, flush, '**', current.copyWith(fontWeight: FontWeight.bold), closer)) {
        continue;
      }
      if (_tryWrap(spans, flush, '__', current.copyWith(fontWeight: FontWeight.bold), closer)) {
        continue;
      }
      if (_tryWrap(spans, flush, '*', current.copyWith(fontStyle: FontStyle.italic), closer)) {
        continue;
      }
      if (_tryWrap(spans, flush, '_', current.copyWith(fontStyle: FontStyle.italic), closer)) {
        continue;
      }
      buffer.writeCharCode(source.codeUnitAt(pos));
      pos += 1;
    }
    flush();
    return spans;
  }

  bool _partialCloser(String closer) {
    if (closer != '*' && closer != '_') return false;
    return _at(closer + closer);
  }

  bool _tryCode(
    List<TextSpan> spans,
    void Function() flush,
    String? closer,
  ) {
    if (closer == '`') return false;
    if (!_at('`')) return false;
    if (_at('```')) return false;
    final saved = pos;
    pos += 1;
    final close = source.indexOf('`', pos);
    if (close == -1) {
      pos = saved;
      return false;
    }
    flush();
    spans.add(TextSpan(text: '`', style: markerStyle));
    spans.add(TextSpan(
      text: source.substring(pos, close),
      style: inlineCodeStyle,
    ));
    spans.add(TextSpan(text: '`', style: markerStyle));
    pos = close + 1;
    return true;
  }

  bool _tryWrap(
    List<TextSpan> spans,
    void Function() flush,
    String delim,
    TextStyle innerStyle,
    String? closer,
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
    final inner = _parse(innerStyle, delim);
    if (pos < source.length && _at(delim)) {
      flush();
      spans.add(TextSpan(text: delim, style: markerStyle));
      spans.addAll(inner);
      spans.add(TextSpan(text: delim, style: markerStyle));
      pos += delim.length;
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
}
