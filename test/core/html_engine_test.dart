import 'package:clean_canvas/core/converter/html_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HtmlEngine engine;

  setUp(() {
    engine = const HtmlEngine();
  });

  group('headings', () {
    test('# Title becomes h1', () {
      expect(engine.markdownToHtml('# Title'), '<h1>Title</h1>');
    });

    test('## Title becomes h2', () {
      expect(engine.markdownToHtml('## Title'), '<h2>Title</h2>');
    });

    test('### Title becomes h3', () {
      expect(engine.markdownToHtml('### Title'), '<h3>Title</h3>');
    });

    test('inline formatting inside a heading is converted', () {
      expect(
        engine.markdownToHtml('# Hello **World**'),
        '<h1>Hello <strong>World</strong></h1>',
      );
    });
  });

  group('inline formatting', () {
    test('**bold** becomes strong', () {
      expect(engine.markdownToHtml('**bold**'), '<p><strong>bold</strong></p>');
    });

    test('__bold__ becomes strong', () {
      expect(engine.markdownToHtml('__bold__'), '<p><strong>bold</strong></p>');
    });

    test('*italic* becomes em', () {
      expect(engine.markdownToHtml('*italic*'), '<p><em>italic</em></p>');
    });

    test('_italic_ becomes em', () {
      expect(engine.markdownToHtml('_italic_'), '<p><em>italic</em></p>');
    });

    test('***bold italic*** nests strong and em', () {
      expect(
        engine.markdownToHtml('***mix***'),
        '<p><strong><em>mix</em></strong></p>',
      );
    });

    test('___bold italic___ nests strong and em', () {
      expect(
        engine.markdownToHtml('___mix___'),
        '<p><strong><em>mix</em></strong></p>',
      );
    });

    test('unmatched markers are left in place', () {
      expect(engine.markdownToHtml('**not closed'), '<p>**not closed</p>');
      expect(engine.markdownToHtml('*not closed'), '<p>*not closed</p>');
    });

    test('snake_case underscores are not treated as italic', () {
      expect(
        engine.markdownToHtml('snake_case_words'),
        '<p>snake_case_words</p>',
      );
    });
  });

  group('mixed formatting within sentences', () {
    test('bold and italic coexist in one paragraph', () {
      expect(
        engine.markdownToHtml('A **bold** and *italic* mix'),
        '<p>A <strong>bold</strong> and <em>italic</em> mix</p>',
      );
    });

    test('italic nested inside bold', () {
      expect(
        engine.markdownToHtml('**bold *italic* still**'),
        '<p><strong>bold <em>italic</em> still</strong></p>',
      );
    });

    test('inline code sits beside emphasis', () {
      expect(
        engine.markdownToHtml('use `x` and **y**'),
        '<p>use <code>x</code> and <strong>y</strong></p>',
      );
    });
  });

  group('unordered lists', () {
    test('hyphen items wrap in a single ul', () {
      expect(
        engine.markdownToHtml('- one\n- two\n- three'),
        '<ul><li>one</li><li>two</li><li>three</li></ul>',
      );
    });

    test('asterisk items wrap in a single ul', () {
      expect(
        engine.markdownToHtml('* alpha\n* beta'),
        '<ul><li>alpha</li><li>beta</li></ul>',
      );
    });

    test('inline formatting inside list items is converted', () {
      expect(
        engine.markdownToHtml('- **bold** item'),
        '<ul><li><strong>bold</strong> item</li></ul>',
      );
    });

    test('*italic* at line start is not treated as a bullet', () {
      expect(engine.markdownToHtml('*italic*'), '<p><em>italic</em></p>');
    });
  });

  group('code', () {
    test('inline code is wrapped in code tags', () {
      expect(engine.markdownToHtml('`Code 42`'), '<p><code>Code 42</code></p>');
    });

    test('markdown inside inline code is not parsed', () {
      expect(
        engine.markdownToHtml('`**not bold**`'),
        '<p><code>**not bold**</code></p>',
      );
    });

    test('fenced code block is wrapped in pre and code', () {
      const input = '```\nvoid main() {}\n```';
      expect(
        engine.markdownToHtml(input),
        '<pre><code>void main() {}</code></pre>',
      );
    });

    test('fenced code with language hint still emits pre/code', () {
      const input = '```dart\nfinal x = 1;\n```';
      expect(
        engine.markdownToHtml(input),
        '<pre><code>final x = 1;</code></pre>',
      );
    });

    test('code block content is HTML-escaped', () {
      const input = '```\n<a> & </a>\n```';
      expect(
        engine.markdownToHtml(input),
        '<pre><code>&lt;a&gt; &amp; &lt;/a&gt;</code></pre>',
      );
    });

    test('multiline code preserves newlines', () {
      const input = '```\nline1\nline2\n```';
      expect(
        engine.markdownToHtml(input),
        '<pre><code>line1\nline2</code></pre>',
      );
    });
  });

  group('blockquotes and paragraphs', () {
    test('> quote becomes blockquote', () {
      expect(
        engine.markdownToHtml('> quoted thought'),
        '<blockquote>quoted thought</blockquote>',
      );
    });

    test('consecutive quote lines join with br', () {
      expect(
        engine.markdownToHtml('> one\n> two'),
        '<blockquote>one<br/>two</blockquote>',
      );
    });

    test('plain text is wrapped in a paragraph', () {
      expect(engine.markdownToHtml('Hello World'), '<p>Hello World</p>');
    });

    test('soft line breaks inside a paragraph become br', () {
      expect(
        engine.markdownToHtml('Hello\nWorld'),
        '<p>Hello<br/>World</p>',
      );
    });

    test('blank lines split paragraphs', () {
      expect(
        engine.markdownToHtml('Hello\n\nWorld'),
        '<p>Hello</p><p>World</p>',
      );
    });

    test('empty input yields empty output', () {
      expect(engine.markdownToHtml(''), '');
      expect(engine.markdownToPlain(''), '');
    });

    test('HTML special characters in prose are escaped', () {
      expect(
        engine.markdownToHtml('a < b & c > d'),
        '<p>a &lt; b &amp; c &gt; d</p>',
      );
    });
  });

  group('dual-payload integrity', () {
    test('plain fallback strips heading, emphasis, and code tokens', () {
      const markdown = '# Hello **world** and *friends* with `code`';
      final html = engine.markdownToHtml(markdown);
      final plain = engine.markdownToPlain(markdown);

      expect(html, '<h1>Hello <strong>world</strong> and '
          '<em>friends</em> with <code>code</code></h1>');
      expect(plain, 'Hello world and friends with code');
      expect(plain, isNot(contains('#')));
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('`')));
    });

    test('plain fallback strips list markers and fence tokens', () {
      const markdown = '- **one**\n- two\n\n```\nraw\n```';
      final html = engine.markdownToHtml(markdown);
      final plain = engine.markdownToPlain(markdown);

      expect(html, contains('<ul><li><strong>one</strong></li><li>two</li></ul>'));
      expect(html, contains('<pre><code>raw</code></pre>'));
      expect(plain, 'one\ntwo\n\nraw');
      expect(plain, isNot(contains('- ')));
      expect(plain, isNot(contains('```')));
      expect(plain, isNot(contains('**')));
    });

    test('plain fallback strips blockquote prefixes', () {
      expect(engine.markdownToPlain('> quoted **bit**'), 'quoted bit');
    });

    test('html and plain stay paired across a mixed document', () {
      const markdown = '# Title\n\nA **bold** line.\n\n- alpha\n- beta';
      final html = engine.markdownToHtml(markdown);
      final plain = engine.markdownToPlain(markdown);

      expect(
        html,
        '<h1>Title</h1><p>A <strong>bold</strong> line.</p>'
        '<ul><li>alpha</li><li>beta</li></ul>',
      );
      expect(plain, 'Title\n\nA bold line.\n\nalpha\nbeta');
    });
  });
}
