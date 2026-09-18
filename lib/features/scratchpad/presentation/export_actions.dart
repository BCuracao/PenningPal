import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clipboard/clipboard_service.dart';
import '../../../core/converter/html_engine.dart';
import '../../../core/converter/unicode_engine.dart';

/// Production clipboard writer. Tests override this with a recording fake.
final clipboardServiceProvider = Provider<ClipboardService>(
  (ref) => const ClipboardService(),
);

final platformExporterProvider = Provider<PlatformExporter>((ref) {
  return PlatformExporter(clipboard: ref.watch(clipboardServiceProvider));
});

/// User-facing copy confirmation copy.
abstract final class ExportMessages {
  static const linkedIn = 'Copied formatted text for LinkedIn!';
  static const x = 'Copied formatted text for X!';
  static const threads = 'Copied formatted text for Threads!';
  static const substack = 'Copied rich text for Substack & Medium!';
}

/// In-memory platform export. Never writes back into the scratchpad buffer.
class PlatformExporter {
  const PlatformExporter({
    this.clipboard = const ClipboardService(),
    this.unicode = const UnicodeEngine(),
    this.html = const HtmlEngine(),
  });

  final ClipboardService clipboard;
  final UnicodeEngine unicode;
  final HtmlEngine html;

  static const int xCharLimit = 280;
  static const int threadsCharLimit = 500;

  static bool isEmptyDraft(String markdown) => markdown.trim().isEmpty;

  /// LinkedIn paste: Mathematical Alphanumeric Unicode, `• ` bullets, hard breaks.
  Future<bool> copyForLinkedIn(String markdown) => _copySocial(markdown);

  /// X (Twitter) paste: same social Unicode conversion as LinkedIn.
  Future<bool> copyForX(String markdown) => _copySocial(markdown);

  /// Threads paste: same social Unicode conversion as X.
  Future<bool> copyForThreads(String markdown) => _copySocial(markdown);

  /// Substack / Medium paste: HTML + stripped plain-text fallback in one write.
  Future<bool> copyForSubstack(String markdown) async {
    if (isEmptyDraft(markdown)) return false;
    await clipboard.copyRichText(
      html: html.markdownToHtml(markdown),
      plainFallback: html.markdownToPlain(markdown),
    );
    return true;
  }

  Future<bool> _copySocial(String markdown) async {
    if (isEmptyDraft(markdown)) return false;
    final converted = unicode.convertForSocial(
      markdown,
      preserveLineBreaks: true,
    );
    await clipboard.copyPlainText(converted);
    return true;
  }
}
