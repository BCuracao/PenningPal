import 'package:clean_canvas/core/converter/unicode_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late UnicodeEngine engine;

  setUp(() {
    engine = const UnicodeEngine();
  });

  group('plain text without formatting', () {
    test('returns identical text', () {
      const input = 'Hello World';
      expect(engine.convertForSocial(input), input);
    });

    test('returns empty string unchanged', () {
      expect(engine.convertForSocial(''), '');
    });

    test('leaves unmatched markers in place', () {
      expect(engine.convertForSocial('**not closed'), '**not closed');
      expect(engine.convertForSocial('*not closed'), '*not closed');
      expect(engine.convertForSocial('`not closed'), '`not closed');
    });
  });

  group('basic bold', () {
    test('**Hello World** maps to mathematical bold', () {
      expect(
        engine.convertForSocial('**Hello World**'),
        '${_b('Hello')} ${_b('World')}',
      );
      expect(
        engine.convertForSocial('**Hello World**'),
        '\u{1D407}\u{1D41E}\u{1D425}\u{1D425}\u{1D428} '
        '\u{1D416}\u{1D428}\u{1D42B}\u{1D425}\u{1D41D}',
      );
    });

    test('underscore bold __Hello__ is equivalent', () {
      expect(engine.convertForSocial('__Hello__'), _b('Hello'));
    });

    test('bold numerals use U+1D7CE range', () {
      expect(engine.convertForSocial('**0123456789**'), _b('0123456789'));
      expect(
        engine.convertForSocial('**0**'),
        String.fromCharCodes([0x1D7CE]),
      );
      expect(
        engine.convertForSocial('**9**'),
        String.fromCharCodes([0x1D7D7]),
      );
    });
  });

  group('punctuation and symbols inside emphasis', () {
    test('only alphanumerics transform inside bold', () {
      expect(
        engine.convertForSocial('**Clean, Canvas! 100%**'),
        '${_b('Clean')}, ${_b('Canvas')}! ${_b('100')}%',
      );
    });

    test('accented Latin letters pass through inside bold', () {
      expect(engine.convertForSocial('**café**'), '${_b('caf')}é');
    });

    test('punctuation inside italic is untouched', () {
      expect(
        engine.convertForSocial('*Hello, world!*'),
        '${_i('Hello')}, ${_i('world')}!',
      );
    });
  });

  group('italic and bold italic', () {
    test('*italic* and _italic_ map to mathematical italic', () {
      expect(engine.convertForSocial('*abc*'), _i('abc'));
      expect(engine.convertForSocial('_xyz_'), _i('xyz'));
    });

    test('italic h uses Planck constant U+210E', () {
      expect(
        engine.convertForSocial('*h*'),
        String.fromCharCodes([0x210E]),
      );
    });

    test('***bold italic*** and ___bold italic___', () {
      expect(engine.convertForSocial('***Hi***'), _bi('Hi'));
      expect(engine.convertForSocial('___Hi___'), _bi('Hi'));
    });

    test('nested bold containing italic becomes bold italic', () {
      expect(
        engine.convertForSocial('**bold *italic* still**'),
        '${_b('bold')} ${_bi('italic')} ${_b('still')}',
      );
    });

    test('snake_case underscores are not treated as italic', () {
      expect(engine.convertForSocial('snake_case_words'), 'snake_case_words');
    });
  });

  group('monospace translation of inline code', () {
    test('inline code maps A-Z a-z 0-9 to monospace', () {
      expect(engine.convertForSocial('`Code 42`'), _m('Code 42'));
    });

    test('markdown inside code spans is not parsed', () {
      expect(engine.convertForSocial('`**not bold**`'), _m('**not bold**'));
    });

    test('code adjacent to prose', () {
      expect(
        engine.convertForSocial('use `x` now'),
        'use ${_m('x')} now',
      );
    });
  });

  group('non-Latin text', () {
    test('Arabic passes through unmodified', () {
      const arabic = 'مرحبا بالعالم';
      expect(engine.convertForSocial(arabic), arabic);
    });

    test('Cyrillic passes through unmodified', () {
      const cyrillic = 'Привет мир';
      expect(engine.convertForSocial(cyrillic), cyrillic);
    });

    test('Chinese passes through unmodified', () {
      const chinese = '你好世界';
      expect(engine.convertForSocial(chinese), chinese);
    });

    test('non-Latin inside bold strips markers but does not map letters', () {
      expect(engine.convertForSocial('**Привет**'), 'Привет');
      expect(engine.convertForSocial('**你好 123**'), '你好 ${_b('123')}');
    });
  });

  group('emojis', () {
    test('standalone emojis pass through without corruption', () {
      const emojis = 'Hello 👋🌍🎉';
      expect(engine.convertForSocial(emojis), emojis);
    });

    test('ZWJ family emoji inside bold stays intact', () {
      const family = '👨‍👩‍👧‍👦';
      expect(engine.convertForSocial('**$family**'), family);
    });

    test('emoji with skin tone modifier is preserved', () {
      const tone = '👍🏽';
      expect(engine.convertForSocial('**$tone**'), tone);
    });
  });

  group('line breaks and bullets', () {
    test('single soft returns become double breaks by default', () {
      expect(engine.convertForSocial('Hello\nWorld'), 'Hello\n\nWorld');
    });

    test('existing paragraph breaks are not expanded further', () {
      expect(engine.convertForSocial('Hello\n\nWorld'), 'Hello\n\nWorld');
    });

    test('preserveLineBreaks: false keeps single newlines', () {
      expect(
        engine.convertForSocial('Hello\nWorld', preserveLineBreaks: false),
        'Hello\nWorld',
      );
    });

    test('unordered - bullets become •', () {
      expect(
        engine.convertForSocial('- one\n- two', preserveLineBreaks: false),
        '• one\n• two',
      );
    });

    test('unordered * bullets become •', () {
      expect(
        engine.convertForSocial('* alpha\n* beta', preserveLineBreaks: false),
        '• alpha\n• beta',
      );
    });

    test('bullets plus default line-break expansion', () {
      expect(engine.convertForSocial('- one\n- two'), '• one\n\n• two');
    });

    test('*italic* at line start is not treated as a bullet', () {
      expect(engine.convertForSocial('*italic*'), _i('italic'));
    });

    test('formatted content inside a bullet is converted', () {
      expect(
        engine.convertForSocial('- **bold** item', preserveLineBreaks: false),
        '• ${_b('bold')} item',
      );
    });
  });

  group('headers', () {
    test('strips # markers and bolds the title', () {
      expect(engine.convertForSocial('# Title'), _b('Title'));
      expect(engine.convertForSocial('## Title'), _b('Title'));
      expect(engine.convertForSocial('### Title'), _b('Title'));
    });

    test('inline italic inside a header becomes bold italic', () {
      expect(
        engine.convertForSocial('# Hello *World*'),
        '${_b('Hello')} ${_bi('World')}',
      );
    });
  });
}

/// Spec-oracle mappers (Unicode scalar offsets from Task 1.2, not the engine).
String _b(String input) => _map(
      input,
      upper: 0x1D400,
      lower: 0x1D41A,
      digit: 0x1D7CE,
    );

String _i(String input) => _map(
      input,
      upper: 0x1D434,
      lower: 0x1D44E,
      italicH: true,
    );

String _bi(String input) => _map(
      input,
      upper: 0x1D468,
      lower: 0x1D482,
      digit: 0x1D7CE,
    );

String _m(String input) => _map(
      input,
      upper: 0x1D670,
      lower: 0x1D68A,
      digit: 0x1D7F6,
    );

String _map(
  String input, {
  required int upper,
  required int lower,
  int? digit,
  bool italicH = false,
}) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x41 && rune <= 0x5A) {
      buffer.write(String.fromCharCodes([upper + (rune - 0x41)]));
    } else if (rune >= 0x61 && rune <= 0x7A) {
      if (italicH && rune == 0x68) {
        buffer.write(String.fromCharCodes([0x210E]));
      } else {
        buffer.write(String.fromCharCodes([lower + (rune - 0x61)]));
      }
    } else if (digit != null && rune >= 0x30 && rune <= 0x39) {
      buffer.write(String.fromCharCodes([digit + (rune - 0x30)]));
    } else {
      buffer.write(String.fromCharCodes([rune]));
    }
  }
  return buffer.toString();
}
