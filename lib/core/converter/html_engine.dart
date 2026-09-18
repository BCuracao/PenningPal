/// Maps Markdown onto clean semantic HTML for Substack / Medium / Docs paste.
///
/// Pure Dart: no Flutter imports. Operates on a copy of the source string and
/// never mutates a stored markdown buffer (screen-reader non-destructive).
class HtmlEngine {
  const HtmlEngine();

  /// Converts [markdown] into semantic HTML (`<p>`, `<h1>`–`<h3>`, `<strong>`,
  /// `<em>`, `<blockquote>`, `<ul><li>`, `<pre><code>`). Inline styles are not
  /// emitted. Special characters in text and code are HTML-escaped.
  String markdownToHtml(String markdown) {
    final blocks = _parseBlocks(_normalize(markdown));
    if (blocks.isEmpty) return '';
    final buffer = StringBuffer();
    for (final block in blocks) {
      buffer.write(block.toHtml());
    }
    return buffer.toString();
  }

  /// Strips Markdown tokens and returns a cleaned plain-text fallback for the
  /// dual MIME clipboard write (`text/html` + `text/plain`).
  String markdownToPlain(String markdown) {
    final blocks = _parseBlocks(_normalize(markdown));
    if (blocks.isEmpty) return '';
    return blocks.map((block) => block.toPlain()).join('\n\n');
  }

  static String _normalize(String markdown) {
    return markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }
}

String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

sealed class _Block {
  const _Block();

  String toHtml();
  String toPlain();
}

final class _Heading extends _Block {
  const _Heading(this.level, this.text);

  final int level;
  final String text;

  @override
  String toHtml() {
    final inner = _InlineParser(text).parseHtml();
    return '<h$level>$inner</h$level>';
  }

  @override
  String toPlain() => _InlineParser(text).parsePlain();
}

final class _Paragraph extends _Block {
  const _Paragraph(this.lines);

  final List<String> lines;

  @override
  String toHtml() {
    final inner = lines.map((line) => _InlineParser(line).parseHtml()).join('<br/>');
    return '<p>$inner</p>';
  }

  @override
  String toPlain() =>
      lines.map((line) => _InlineParser(line).parsePlain()).join('\n');
}

final class _ListBlock extends _Block {
  const _ListBlock(this.items);

  final List<String> items;

  @override
  String toHtml() {
    final buffer = StringBuffer('<ul>');
    for (final item in items) {
      buffer.write('<li>${_InlineParser(item).parseHtml()}</li>');
    }
    buffer.write('</ul>');
    return buffer.toString();
  }

  @override
  String toPlain() =>
      items.map((item) => _InlineParser(item).parsePlain()).join('\n');
}

final class _Quote extends _Block {
  const _Quote(this.lines);

  final List<String> lines;

  @override
  String toHtml() {
    final inner =
        lines.map((line) => _InlineParser(line).parseHtml()).join('<br/>');
    return '<blockquote>$inner</blockquote>';
  }

  @override
  String toPlain() =>
      lines.map((line) => _InlineParser(line).parsePlain()).join('\n');
}

final class _CodeBlock extends _Block {
  const _CodeBlock(this.content);

  final String content;

  @override
  String toHtml() => '<pre><code>${_escapeHtml(content)}</code></pre>';

  @override
  String toPlain() => content;
}

List<_Block> _parseBlocks(String markdown) {
  if (markdown.isEmpty) return const [];

  final lines = markdown.split('\n');
  final blocks = <_Block>[];
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    if (line.startsWith('```')) {
      i++;
      final codeLines = <String>[];
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      if (i < lines.length && lines[i].startsWith('```')) {
        i++;
      }
      blocks.add(_CodeBlock(codeLines.join('\n')));
      continue;
    }

    final header = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
    if (header != null) {
      blocks.add(_Heading(header.group(1)!.length, header.group(2)!));
      i++;
      continue;
    }

    if (_isQuote(line)) {
      final quoteLines = <String>[];
      while (i < lines.length && _isQuote(lines[i])) {
        quoteLines.add(_quoteBody(lines[i]));
        i++;
      }
      blocks.add(_Quote(quoteLines));
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
      blocks.add(_Paragraph(paraLines));
    }
  }

  return blocks;
}

bool _isBlockStart(String line) {
  if (line.startsWith('```')) return true;
  if (RegExp(r'^(#{1,3}) ').hasMatch(line)) return true;
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

class _InlineParser {
  _InlineParser(this.source);

  final String source;
  int pos = 0;

  String parseHtml() => _parse(escape: true, wrap: true);

  String parsePlain() => _parse(escape: false, wrap: false);

  String _parse({
    required bool escape,
    required bool wrap,
    String? closer,
  }) {
    final buffer = StringBuffer();
    while (pos < source.length) {
      if (_tryCode(buffer, wrap: wrap, closer: closer)) {
        continue;
      }
      if (_tryOpen('***', buffer, escape, wrap, closer, htmlOpen: '<strong><em>', htmlClose: '</em></strong>')) {
        continue;
      }
      if (_tryOpen('___', buffer, escape, wrap, closer, htmlOpen: '<strong><em>', htmlClose: '</em></strong>')) {
        continue;
      }
      if (_tryOpen('**', buffer, escape, wrap, closer, htmlOpen: '<strong>', htmlClose: '</strong>')) {
        continue;
      }
      if (_tryOpen('__', buffer, escape, wrap, closer, htmlOpen: '<strong>', htmlClose: '</strong>')) {
        continue;
      }
      if (_tryOpen('*', buffer, escape, wrap, closer, htmlOpen: '<em>', htmlClose: '</em>')) {
        continue;
      }
      if (_tryOpen('_', buffer, escape, wrap, closer, htmlOpen: '<em>', htmlClose: '</em>')) {
        continue;
      }
      if (closer != null && _at(closer)) {
        break;
      }
      _emitRune(buffer, escape: escape);
    }
    return buffer.toString();
  }

  bool _tryCode(
    StringBuffer buffer, {
    required bool wrap,
    String? closer,
  }) {
    if (!_at('`')) return false;
    if (closer != null && closer == '`') return false;

    final saved = pos;
    pos += 1;
    final close = source.indexOf('`', pos);
    if (close == -1) {
      pos = saved;
      return false;
    }
    final inner = source.substring(pos, close);
    if (wrap) {
      buffer.write('<code>${_escapeHtml(inner)}</code>');
    } else {
      buffer.write(inner);
    }
    pos = close + 1;
    return true;
  }

  bool _tryOpen(
    String delim,
    StringBuffer buffer,
    bool escape,
    bool wrap,
    String? closer, {
    required String htmlOpen,
    required String htmlClose,
  }) {
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
    final inner = _parse(escape: escape, wrap: wrap, closer: delim);
    if (pos < source.length && _at(delim)) {
      pos += delim.length;
      if (wrap) {
        buffer
          ..write(htmlOpen)
          ..write(inner)
          ..write(htmlClose);
      } else {
        buffer.write(inner);
      }
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

  void _emitRune(StringBuffer buffer, {required bool escape}) {
    final rune = _codePointAt(pos);
    final char = String.fromCharCodes([rune]);
    buffer.write(escape ? _escapeHtml(char) : char);
    pos += rune > 0xFFFF ? 2 : 1;
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
