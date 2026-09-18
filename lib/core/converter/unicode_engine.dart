/// Maps Markdown emphasis onto Mathematical Alphanumeric Symbols for social paste.
///
/// Pure Dart: no Flutter imports. Operates on a copy of the source string and
/// never mutates a stored markdown buffer (screen-reader non-destructive).
class UnicodeEngine {
  const UnicodeEngine();

  /// Converts [markdownText] into a Unicode-styled string suitable for
  /// LinkedIn / X paste.
  ///
  /// When [preserveLineBreaks] is true, isolated `\n` are expanded to `\n\n`
  /// so platforms that collapse soft breaks still show a visual line break.
  String convertForSocial(
    String markdownText, {
    bool preserveLineBreaks = true,
  }) {
    final normalized = markdownText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final converted = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) converted.write('\n');
      converted.write(_convertLine(lines[i]));
    }
    var result = converted.toString();
    if (preserveLineBreaks) {
      result = result.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), '\n\n');
    }
    return result;
  }

  String _convertLine(String line) {
    final header = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
    if (header != null) {
      return _InlineParser(header.group(2)!).parse(_UnicodeStyle.bold);
    }

    final bullet = RegExp(r'^(\s*)([-*]) (.*)$').firstMatch(line);
    if (bullet != null) {
      final indent = bullet.group(1)!;
      final body = _InlineParser(bullet.group(3)!).parse(_UnicodeStyle.none);
      return '$indent• $body';
    }

    return _InlineParser(line).parse(_UnicodeStyle.none);
  }
}

enum _UnicodeStyle { none, bold, italic, boldItalic, monospace }

_UnicodeStyle _combine(_UnicodeStyle outer, _UnicodeStyle add) {
  if (outer == _UnicodeStyle.monospace || add == _UnicodeStyle.monospace) {
    return _UnicodeStyle.monospace;
  }
  final bold = outer == _UnicodeStyle.bold ||
      outer == _UnicodeStyle.boldItalic ||
      add == _UnicodeStyle.bold ||
      add == _UnicodeStyle.boldItalic;
  final italic = outer == _UnicodeStyle.italic ||
      outer == _UnicodeStyle.boldItalic ||
      add == _UnicodeStyle.italic ||
      add == _UnicodeStyle.boldItalic;
  if (bold && italic) return _UnicodeStyle.boldItalic;
  if (bold) return _UnicodeStyle.bold;
  if (italic) return _UnicodeStyle.italic;
  return _UnicodeStyle.none;
}

/// Mathematical italic small h is unassigned at U+1D455; use Planck constant.
const int _italicSmallH = 0x210E;

String _mapString(String text, _UnicodeStyle style) {
  if (style == _UnicodeStyle.none || text.isEmpty) return text;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    buffer.write(_mapRune(rune, style));
  }
  return buffer.toString();
}

String _mapRune(int rune, _UnicodeStyle style) {
  if (style == _UnicodeStyle.none) {
    return String.fromCharCodes([rune]);
  }

  if (rune >= 0x41 && rune <= 0x5A) {
    final offset = rune - 0x41;
    switch (style) {
      case _UnicodeStyle.bold:
        return String.fromCharCodes([0x1D400 + offset]);
      case _UnicodeStyle.italic:
        return String.fromCharCodes([0x1D434 + offset]);
      case _UnicodeStyle.boldItalic:
        return String.fromCharCodes([0x1D468 + offset]);
      case _UnicodeStyle.monospace:
        return String.fromCharCodes([0x1D670 + offset]);
      case _UnicodeStyle.none:
        break;
    }
  } else if (rune >= 0x61 && rune <= 0x7A) {
    final offset = rune - 0x61;
    switch (style) {
      case _UnicodeStyle.bold:
        return String.fromCharCodes([0x1D41A + offset]);
      case _UnicodeStyle.italic:
        if (rune == 0x68) return String.fromCharCodes([_italicSmallH]);
        return String.fromCharCodes([0x1D44E + offset]);
      case _UnicodeStyle.boldItalic:
        return String.fromCharCodes([0x1D482 + offset]);
      case _UnicodeStyle.monospace:
        return String.fromCharCodes([0x1D68A + offset]);
      case _UnicodeStyle.none:
        break;
    }
  } else if (rune >= 0x30 && rune <= 0x39) {
    final offset = rune - 0x30;
    switch (style) {
      case _UnicodeStyle.bold:
      case _UnicodeStyle.boldItalic:
        return String.fromCharCodes([0x1D7CE + offset]);
      case _UnicodeStyle.monospace:
        return String.fromCharCodes([0x1D7F6 + offset]);
      case _UnicodeStyle.italic:
      case _UnicodeStyle.none:
        break;
    }
  }

  // Punctuation, symbols, emojis, accented Latin, and non-Latin scripts.
  return String.fromCharCodes([rune]);
}

class _InlineParser {
  _InlineParser(this.source);

  final String source;
  int pos = 0;

  String parse(_UnicodeStyle style, [String? closer]) {
    final buffer = StringBuffer();
    while (pos < source.length) {
      if (_tryOpen('`', style, buffer, _UnicodeStyle.monospace, closer, raw: true)) {
        continue;
      }
      if (_tryOpen('***', style, buffer, _UnicodeStyle.boldItalic, closer)) {
        continue;
      }
      if (_tryOpen('___', style, buffer, _UnicodeStyle.boldItalic, closer)) {
        continue;
      }
      if (_tryOpen('**', style, buffer, _UnicodeStyle.bold, closer)) {
        continue;
      }
      if (_tryOpen('__', style, buffer, _UnicodeStyle.bold, closer)) {
        continue;
      }
      if (_tryOpen('*', style, buffer, _UnicodeStyle.italic, closer)) {
        continue;
      }
      if (_tryOpen('_', style, buffer, _UnicodeStyle.italic, closer)) {
        continue;
      }
      if (closer != null && _at(closer)) {
        break;
      }
      _emitRune(buffer, style);
    }
    return buffer.toString();
  }

  bool _tryOpen(
    String delim,
    _UnicodeStyle outer,
    StringBuffer buffer,
    _UnicodeStyle add,
    String? closer, {
    bool raw = false,
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

    if (raw) {
      final close = source.indexOf(delim, pos);
      if (close == -1) {
        pos = saved;
        return false;
      }
      buffer.write(_mapString(source.substring(pos, close), _UnicodeStyle.monospace));
      pos = close + delim.length;
      return true;
    }

    final inner = parse(_combine(outer, add), delim);
    if (pos < source.length && _at(delim)) {
      pos += delim.length;
      buffer.write(inner);
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

  void _emitRune(StringBuffer buffer, _UnicodeStyle style) {
    final rune = _codePointAt(pos);
    buffer.write(_mapRune(rune, style));
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
