/// Splits slide markdown into prose and fenced code blocks.
///
/// Pure Dart: no Flutter imports. Operates on a copy of the source string
/// and never mutates a stored markdown buffer.
class CodeBlockParser {
  const CodeBlockParser();

  /// Languages the on-device highlighter can color. Aliases map onto
  /// highlight.js ids used by `package:highlight`.
  static const Map<String, String> recognizedLanguages = {
    'dart': 'dart',
    'js': 'javascript',
    'javascript': 'javascript',
    'ts': 'typescript',
    'typescript': 'typescript',
    'python': 'python',
    'py': 'python',
    'swift': 'swift',
    'rust': 'rust',
    'rs': 'rust',
    'json': 'json',
    'kotlin': 'kotlin',
    'kt': 'kotlin',
    'java': 'java',
    'go': 'go',
    'golang': 'go',
    'html': 'xml',
    'xml': 'xml',
    'css': 'css',
    'yaml': 'yaml',
    'yml': 'yaml',
    'bash': 'bash',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'sql': 'sql',
    'c': 'cpp',
    'cpp': 'cpp',
    'c++': 'cpp',
    'csharp': 'cs',
    'cs': 'cs',
    'c#': 'cs',
    'ruby': 'ruby',
    'rb': 'ruby',
    'php': 'php',
  };

  /// Returns the highlight.js language id, or `null` when [tag] is missing
  /// or not in [recognizedLanguages] (plain monospace fallback).
  static String? resolveLanguage(String? tag) {
    if (tag == null) return null;
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return recognizedLanguages[normalized];
  }

  /// Parses fenced blocks of the form ` ```[lang]\n[code]\n``` `.
  ///
  /// Surrounding prose is preserved as [ProseSegment]s. Unclosed fences
  /// consume the remainder of the document as code.
  ParsedCardContent parse(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.isEmpty) {
      return const ParsedCardContent([]);
    }

    final lines = normalized.split('\n');
    final segments = <CardContentSegment>[];
    final prose = <String>[];

    void flushProse() {
      final text = prose.join('\n').trim();
      prose.clear();
      if (text.isNotEmpty) {
        segments.add(ProseSegment(text));
      }
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (_isFence(line)) {
        flushProse();
        final language = _languageOf(line);
        i++;
        final codeLines = <String>[];
        while (i < lines.length && !_isFence(lines[i])) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && _isFence(lines[i])) {
          i++;
        }
        segments.add(
          CodeBlockSegment(
            code: codeLines.join('\n'),
            language: language,
          ),
        );
        continue;
      }
      prose.add(line);
      i++;
    }
    flushProse();
    return ParsedCardContent(List.unmodifiable(segments));
  }

  static bool _isFence(String line) => line.trimLeft().startsWith('```');

  static String? _languageOf(String fenceLine) {
    final trimmed = fenceLine.trimLeft();
    final rest = trimmed.substring(3).trim();
    if (rest.isEmpty) return null;
    final tag = rest.split(RegExp(r'\s+')).first;
    if (tag.isEmpty) return null;
    return tag;
  }
}

/// Ordered prose / code segments extracted from a slide.
class ParsedCardContent {
  const ParsedCardContent(this.segments);

  final List<CardContentSegment> segments;

  bool get isEmpty => segments.isEmpty;

  bool get hasCode => segments.any((segment) => segment is CodeBlockSegment);

  /// True when the slide is a single fenced block with no surrounding prose.
  bool get isCodeOnly =>
      segments.length == 1 && segments.first is CodeBlockSegment;
}

sealed class CardContentSegment {
  const CardContentSegment();
}

final class ProseSegment extends CardContentSegment {
  const ProseSegment(this.text);

  final String text;
}

final class CodeBlockSegment extends CardContentSegment {
  const CodeBlockSegment({required this.code, this.language});

  /// Raw fenced body, not mutated.
  final String code;

  /// Language tag as authored (may be unrecognized). `null` if omitted.
  final String? language;

  /// highlight.js id, or `null` for the plain-monospace fallback.
  String? get highlightLanguage => CodeBlockParser.resolveLanguage(language);

  bool get isHighlighted => highlightLanguage != null;
}
