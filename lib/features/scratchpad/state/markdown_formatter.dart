/// Pure string edits for scratchpad markdown. No Flutter imports.
///
/// Operates on a copy of the source buffer and never mutates it in place, so
/// the stored markdown stays screen-reader-safe (raw tokens, not Unicode).
class MarkdownEditResult {
  const MarkdownEditResult({
    required this.text,
    required this.selectionStart,
    required this.selectionEnd,
  });

  final String text;
  final int selectionStart;
  final int selectionEnd;
}

/// Inserts and toggles markdown tokens around a selection or cursor.
class MarkdownFormatter {
  const MarkdownFormatter();

  static const String slideBreak = '\n\n---\n\n';

  MarkdownEditResult toggleBold(String text, int start, int end) {
    return _wrapOrUnwrap(
      text,
      start,
      end,
      open: '**',
      close: '**',
      placeholder: 'bold',
    );
  }

  MarkdownEditResult toggleItalic(String text, int start, int end) {
    return _wrapOrUnwrap(
      text,
      start,
      end,
      open: '*',
      close: '*',
      placeholder: 'italic',
    );
  }

  MarkdownEditResult toggleInlineCode(String text, int start, int end) {
    return toggleCode(text, start, end);
  }

  /// Inline `` `code` `` for a caret / single line; fenced block when the
  /// selection spans more than one line.
  MarkdownEditResult toggleCode(String text, int start, int end) {
    final range = _normalize(text, start, end);
    final selected = text.substring(range.start, range.end);
    if (selected.contains('\n')) {
      return _wrapOrUnwrap(
        text,
        range.start,
        range.end,
        open: '```\n',
        close: '\n```',
        placeholder: 'code',
      );
    }
    return _wrapOrUnwrap(
      text,
      range.start,
      range.end,
      open: '`',
      close: '`',
      placeholder: 'code',
    );
  }

  /// Cycles the line at the cursor through `# `, `## `, `### `, then body text.
  MarkdownEditResult cycleHeading(String text, int start, int end) {
    final range = _normalize(text, start, end);
    final lineStart = _lineStart(text, range.start);
    final lineEnd = _lineEnd(text, range.start);
    final line = text.substring(lineStart, lineEnd);

    final match = RegExp(r'^(#{1,3})(\s*)').firstMatch(line);
    final oldPrefixLen = match == null ? 0 : match.group(0)!.length;
    final rest = match == null ? line : line.substring(oldPrefixLen);
    final level = match == null ? 0 : match.group(1)!.length;

    final String newPrefix;
    if (level == 0) {
      newPrefix = '# ';
    } else if (level < 3) {
      newPrefix = '${'#' * (level + 1)} ';
    } else {
      newPrefix = '';
    }

    final newLine = '$newPrefix$rest';
    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    return MarkdownEditResult(
      text: newText,
      selectionStart: _shift(
        range.start,
        lineStart,
        oldPrefixLen,
        newPrefix.length,
      ),
      selectionEnd: _shift(
        range.end,
        lineStart,
        oldPrefixLen,
        newPrefix.length,
      ),
    );
  }

  /// Toggles a `- ` list marker at the start of the current line.
  MarkdownEditResult toggleBullet(String text, int start, int end) {
    return _toggleLinePrefix(
      text,
      start,
      end,
      prefix: '- ',
      hasPrefix: (line) => RegExp(r'^[-*+][ \t]+').hasMatch(line),
      stripPrefix: (line) => line.replaceFirst(RegExp(r'^[-*+][ \t]+'), ''),
    );
  }

  /// Toggles a `> ` quote marker at the start of the current line.
  MarkdownEditResult toggleQuote(String text, int start, int end) {
    return _toggleLinePrefix(
      text,
      start,
      end,
      prefix: '> ',
      hasPrefix: (line) => RegExp(r'^>[ \t]?').hasMatch(line),
      stripPrefix: (line) => line.replaceFirst(RegExp(r'^>[ \t]?'), ''),
    );
  }

  /// Inserts a carousel thematic break at the cursor (`\n\n---\n\n`).
  MarkdownEditResult insertSlideBreak(String text, int start, int end) {
    final range = _normalize(text, start, end);
    final insertion = slideBreak;
    final newText =
        text.substring(0, range.start) + insertion + text.substring(range.start);
    final caret = range.start + insertion.length;
    return MarkdownEditResult(
      text: newText,
      selectionStart: caret,
      selectionEnd: caret,
    );
  }

  MarkdownEditResult _toggleLinePrefix(
    String text,
    int start,
    int end, {
    required String prefix,
    required bool Function(String line) hasPrefix,
    required String Function(String line) stripPrefix,
  }) {
    final range = _normalize(text, start, end);
    final lineStart = _lineStart(text, range.start);
    final lineEnd = _lineEnd(text, range.start);
    final line = text.substring(lineStart, lineEnd);

    final bool removing = hasPrefix(line);
    final String newLine;
    final int oldPrefixLen;
    final int newPrefixLen;
    if (removing) {
      newLine = stripPrefix(line);
      oldPrefixLen = line.length - newLine.length;
      newPrefixLen = 0;
    } else {
      newLine = '$prefix$line';
      oldPrefixLen = 0;
      newPrefixLen = prefix.length;
    }

    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    return MarkdownEditResult(
      text: newText,
      selectionStart: _shift(
        range.start,
        lineStart,
        oldPrefixLen,
        newPrefixLen,
      ),
      selectionEnd: _shift(
        range.end,
        lineStart,
        oldPrefixLen,
        newPrefixLen,
      ),
    );
  }

  MarkdownEditResult _wrapOrUnwrap(
    String text,
    int start,
    int end, {
    required String open,
    required String close,
    required String placeholder,
  }) {
    final range = _normalize(text, start, end);

    if (_isWrappedBy(text, range.start, range.end, open, close)) {
      final inner = text.substring(range.start, range.end);
      final newText = text.substring(0, range.start - open.length) +
          inner +
          text.substring(range.end + close.length);
      return MarkdownEditResult(
        text: newText,
        selectionStart: range.start - open.length,
        selectionEnd: range.start - open.length + inner.length,
      );
    }

    final selected = text.substring(range.start, range.end);
    if (selected.length >= open.length + close.length &&
        selected.startsWith(open) &&
        selected.endsWith(close) &&
        !_isAmbiguousItalicOfBold(open, selected)) {
      final inner = selected.substring(open.length, selected.length - close.length);
      final newText =
          text.substring(0, range.start) + inner + text.substring(range.end);
      return MarkdownEditResult(
        text: newText,
        selectionStart: range.start,
        selectionEnd: range.start + inner.length,
      );
    }

    if (range.start == range.end) {
      final insertion = '$open$placeholder$close';
      final newText = text.substring(0, range.start) +
          insertion +
          text.substring(range.end);
      return MarkdownEditResult(
        text: newText,
        selectionStart: range.start + open.length,
        selectionEnd: range.start + open.length + placeholder.length,
      );
    }

    final wrapped = '$open$selected$close';
    final newText =
        text.substring(0, range.start) + wrapped + text.substring(range.end);
    return MarkdownEditResult(
      text: newText,
      selectionStart: range.start + open.length,
      selectionEnd: range.start + open.length + selected.length,
    );
  }

  /// `*hello*` unwrap must not treat the inner stars of `**hello**` as italic.
  bool _isWrappedBy(
    String text,
    int start,
    int end,
    String open,
    String close,
  ) {
    if (start < open.length || end + close.length > text.length) return false;
    if (text.substring(start - open.length, start) != open) return false;
    if (text.substring(end, end + close.length) != close) return false;
    if (open == '*' && close == '*') {
      final extraBefore = start >= 2 && text[start - 2] == '*';
      final extraAfter = end + 1 < text.length && text[end + 1] == '*';
      if (extraBefore && extraAfter) return false;
    }
    if (open == '_' && close == '_') {
      final extraBefore = start >= 2 && text[start - 2] == '_';
      final extraAfter = end + 1 < text.length && text[end + 1] == '_';
      if (extraBefore && extraAfter) return false;
    }
    return true;
  }

  bool _isAmbiguousItalicOfBold(String open, String selected) {
    if (open != '*') return false;
    return selected.startsWith('**') && selected.endsWith('**');
  }

  ({int start, int end}) _normalize(String text, int start, int end) {
    var s = start;
    var e = end;
    if (s > e) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    s = s.clamp(0, text.length);
    e = e.clamp(0, text.length);
    return (start: s, end: e);
  }

  int _lineStart(String text, int offset) {
    if (offset <= 0) return 0;
    return text.lastIndexOf('\n', offset - 1) + 1;
  }

  int _lineEnd(String text, int offset) {
    final i = text.indexOf('\n', offset);
    return i == -1 ? text.length : i;
  }

  int _shift(int offset, int lineStart, int oldPrefixLen, int newPrefixLen) {
    if (offset <= lineStart) return offset;
    final relative = offset - lineStart;
    if (relative <= oldPrefixLen) {
      return lineStart + newPrefixLen;
    }
    return offset + (newPrefixLen - oldPrefixLen);
  }
}
