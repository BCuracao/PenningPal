import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Custom block stored in the Quill document for a carousel slide divider.
///
/// The editor paints this as a banner. [deltaToMarkdown] writes it back as a
/// markdown thematic break (`---`) so [CarouselDeck] keeps the same slide count.
class SlideBreakEmbed extends CustomBlockEmbed {
  const SlideBreakEmbed() : super(embedType, 'break');

  static const String embedType = 'slideBreak';

  /// Delta insert payload (`{custom: "{\"slideBreak\":\"break\"}"}`).
  static Map<String, dynamic> get insertData =>
      BlockEmbed.custom(const SlideBreakEmbed()).toJson();
}

/// True when a Delta insert is a [SlideBreakEmbed].
bool isSlideBreakEmbed(Object? data) {
  if (data is! Map) return false;
  final map = Map<String, dynamic>.from(data);
  if (map.containsKey(SlideBreakEmbed.embedType)) return true;
  final custom = map[BlockEmbed.customType];
  if (custom is! String) return false;
  try {
    return CustomBlockEmbed.fromJsonString(custom).type == SlideBreakEmbed.embedType;
  } on FormatException {
    return false;
  } on TypeError {
    return false;
  }
}

/// Converts standard Markdown into a Quill [Delta].
///
/// Headings, emphasis, quotes, lists, fenced code, and thematic breaks become
/// document attributes and a slide-break embed. The returned delta always ends
/// with a newline, which Quill requires.
Delta markdownToDelta(String markdown) {
  final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.isEmpty) {
    return Delta()..insert('\n');
  }

  final delta = Delta();
  final lines = normalized.split('\n');
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    final fence = _fenceLanguage(line);
    if (fence != null) {
      final body = <String>[];
      index++;
      while (index < lines.length && _fenceLanguage(lines[index]) == null) {
        body.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++;
      final language = fence.trim();
      final codeAttrs = <String, dynamic>{
        'code-block': language.isEmpty ? true : language,
      };
      if (body.isEmpty) {
        delta.insert('\n', codeAttrs);
      } else {
        for (final codeLine in body) {
          if (codeLine.isNotEmpty) delta.insert(codeLine);
          delta.insert('\n', codeAttrs);
        }
      }
      continue;
    }

    if (_thematicBreak.hasMatch(line)) {
      delta
        ..insert(SlideBreakEmbed.insertData)
        ..insert('\n');
      index++;
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      _insertInline(delta, heading.group(2) ?? '');
      delta.insert('\n', {'header': heading.group(1)!.length});
      index++;
      continue;
    }

    final quote = _quote.firstMatch(line);
    if (quote != null) {
      _insertInline(delta, quote.group(1) ?? '');
      delta.insert('\n', {'blockquote': true});
      index++;
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      _insertInline(delta, bullet.group(1) ?? '');
      delta.insert('\n', {'list': 'bullet'});
      index++;
      continue;
    }

    if (line.isNotEmpty) _insertInline(delta, line);
    delta.insert('\n');
    index++;
  }

  final ops = delta.toList();
  final last = ops.isEmpty ? null : ops.last.data;
  if (last is! String || !last.endsWith('\n')) {
    delta.insert('\n');
  }
  return delta;
}

/// Serializes a Quill [Delta] back to clean Markdown.
///
/// Slide-break embeds become `---`. Emphasis is written with `*` / `**`,
/// headings with `#`, quotes with `>`, and bullets with `- `.
String deltaToMarkdown(Delta delta) {
  final lines = <_MdLine>[];
  final runs = <_MdRun>[];
  var slide = false;

  void endLine(Map<String, dynamic>? attributes) {
    lines.add(
      _MdLine(
        runs: List<_MdRun>.from(runs),
        attributes: attributes ?? const {},
        isSlide: slide,
      ),
    );
    runs.clear();
    slide = false;
  }

  for (final op in delta.toList()) {
    if (!op.isInsert) continue;
    final data = op.data;
    if (isSlideBreakEmbed(data)) {
      if (runs.isNotEmpty) endLine(null);
      slide = true;
      continue;
    }
    if (data is! String) continue;
    final attrs = op.attributes;
    var start = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i] != '\n') continue;
      if (i > start) {
        runs.add(_MdRun(data.substring(start, i), _inlineAttrs(attrs)));
      }
      endLine(attrs);
      start = i + 1;
    }
    if (start < data.length) {
      runs.add(_MdRun(data.substring(start), _inlineAttrs(attrs)));
    }
  }
  if (runs.isNotEmpty || slide) endLine(null);

  final blocks = <String>[];
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    if (line.isCodeBlock) {
      final lang = line.codeLanguage;
      final body = <String>[];
      while (index < lines.length && lines[index].isCodeBlock) {
        body.add(lines[index].plainText);
        index++;
      }
      final info = lang == null || lang.isEmpty ? '' : lang;
      blocks.add('```$info\n${body.join('\n')}\n```');
      continue;
    }
    blocks.add(line.render());
    index++;
  }
  return blocks.join('\n');
}

final RegExp _thematicBreak = RegExp(
  r'^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$',
);
final RegExp _heading = RegExp(r'^(#{1,6})[ \t]+(.*)$');
final RegExp _quote = RegExp(r'^[ \t]*>[ \t]?(.*)$');
final RegExp _bullet = RegExp(r'^[ \t]*[-*+][ \t]+(.*)$');
final RegExp _fence = RegExp(r'^[ \t]*```([^`]*)\s*$');
final RegExp _wordChar = RegExp(r'[A-Za-z0-9_]');

const Set<String> _blockAttributeKeys = {
  'header',
  'list',
  'blockquote',
  'code-block',
  'indent',
  'align',
  'direction',
};

String? _fenceLanguage(String line) => _fence.firstMatch(line)?.group(1);

void _insertInline(Delta delta, String text) {
  for (final run in _parseInline(text)) {
    if (run.text.isEmpty) continue;
    if (run.attributes.isEmpty) {
      delta.insert(run.text);
    } else {
      delta.insert(run.text, run.attributes);
    }
  }
}

Map<String, dynamic> _inlineAttrs(Map<String, dynamic>? attributes) {
  if (attributes == null || attributes.isEmpty) return const {};
  final inline = <String, dynamic>{};
  for (final entry in attributes.entries) {
    if (_blockAttributeKeys.contains(entry.key)) continue;
    if (entry.value == null || entry.value == false) continue;
    if (entry.key == 'bold' || entry.key == 'italic' || entry.key == 'code') {
      inline[entry.key] = entry.value;
    }
  }
  return inline;
}

class _MdRun {
  const _MdRun(this.text, [this.attributes = const {}]);

  final String text;
  final Map<String, dynamic> attributes;

  bool sameStyle(_MdRun other) {
    if (attributes.length != other.attributes.length) return false;
    for (final entry in attributes.entries) {
      if (other.attributes[entry.key] != entry.value) return false;
    }
    return true;
  }
}

class _MdLine {
  const _MdLine({
    required this.runs,
    required this.attributes,
    required this.isSlide,
  });

  final List<_MdRun> runs;
  final Map<String, dynamic> attributes;
  final bool isSlide;

  bool get isCodeBlock =>
      !isSlide && attributes.containsKey('code-block');

  String? get codeLanguage {
    final value = attributes['code-block'];
    if (value is String && value != 'true') return value;
    return null;
  }

  String get plainText => runs.map((run) => run.text).join();

  String render() {
    if (isSlide) return '---';
    final text = _renderInline(runs);
    final header = attributes['header'];
    if (header is num && header >= 1) {
      final level = header.toInt().clamp(1, 6);
      return '${'#' * level} $text';
    }
    if (attributes['blockquote'] == true) {
      return text.isEmpty ? '>' : '> $text';
    }
    final list = attributes['list'];
    if (list == 'bullet' || list == 'checked' || list == 'unchecked') {
      return '- $text';
    }
    if (list == 'ordered') return '1. $text';
    return text;
  }
}

String _renderInline(List<_MdRun> runs) {
  final merged = <_MdRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (merged.isNotEmpty && merged.last.sameStyle(run)) {
      final previous = merged.removeLast();
      merged.add(_MdRun(previous.text + run.text, previous.attributes));
    } else {
      merged.add(run);
    }
  }
  return merged.map(_wrapRun).join();
}

String _wrapRun(_MdRun run) {
  var text = run.text;
  if (run.attributes['code'] == true) text = '`$text`';
  final bold = run.attributes['bold'] == true;
  final italic = run.attributes['italic'] == true;
  if (bold && italic) return '***$text***';
  if (bold) return '**$text**';
  if (italic) return '*$text*';
  return text;
}

List<_MdRun> _parseInline(String input) {
  final runs = <_MdRun>[];
  final buffer = StringBuffer();
  var index = 0;

  void flush() {
    if (buffer.isEmpty) return;
    runs.add(_MdRun(buffer.toString()));
    buffer.clear();
  }

  while (index < input.length) {
    if (input[index] == '`') {
      final close = input.indexOf('`', index + 1);
      if (close > index + 1) {
        flush();
        runs.add(_MdRun(input.substring(index + 1, close), const {'code': true}));
        index = close + 1;
        continue;
      }
    }

    final marker = _openingMarker(input, index);
    if (marker != null) {
      final close = _findClose(input, index + marker.length, marker);
      if (close != null && close > index + marker.length) {
        flush();
        final inner = _parseInline(input.substring(index + marker.length, close));
        final style = _styleForMarker(marker);
        for (final run in inner) {
          runs.add(_MdRun(run.text, {...run.attributes, ...style}));
        }
        index = close + marker.length;
        continue;
      }
    }

    buffer.write(input[index]);
    index++;
  }
  flush();
  return runs;
}

const List<String> _markers = ['***', '___', '**', '__', '*', '_'];

String? _openingMarker(String input, int index) {
  for (final marker in _markers) {
    if (!input.startsWith(marker, index)) continue;
    if (marker[0] == '_' && !_canUseUnderscore(input, index, marker.length)) {
      continue;
    }
    final close = _findClose(input, index + marker.length, marker);
    if (close == null || close == index + marker.length) continue;
    if (marker[0] == '_' && !_canCloseUnderscore(input, close, marker.length)) {
      continue;
    }
    return marker;
  }
  return null;
}

bool _canUseUnderscore(String input, int index, int length) {
  if (index > 0 && _wordChar.hasMatch(input[index - 1])) return false;
  final next = index + length;
  if (next < input.length && input[next] == ' ') return false;
  return true;
}

bool _canCloseUnderscore(String input, int close, int length) {
  final after = close + length;
  if (after < input.length && _wordChar.hasMatch(input[after])) return false;
  return true;
}

int? _findClose(String input, int from, String marker) {
  var index = from;
  while (index < input.length) {
    if (input.startsWith(marker, index)) {
      final next = index + marker.length;
      final continues = next < input.length && input[next] == marker[0];
      if (!continues) return index;
    }
    index++;
  }
  return null;
}

Map<String, dynamic> _styleForMarker(String marker) {
  switch (marker) {
    case '***':
    case '___':
      return const {'bold': true, 'italic': true};
    case '**':
    case '__':
      return const {'bold': true};
    case '*':
    case '_':
      return const {'italic': true};
    default:
      return const {};
  }
}
