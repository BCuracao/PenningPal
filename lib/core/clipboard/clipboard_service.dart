import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Multi-MIME system clipboard writer for plain and rich (HTML) paste targets.
///
/// Rich copies write `text/html` and a cleaned `text/plain` fallback in a
/// single [DataWriterItem] so Substack, Medium, Google Docs, and plain-text
/// fields all receive a compatible payload.
class ClipboardService {
  const ClipboardService();

  /// Writes a plain-text clipboard item.
  Future<void> copyPlainText(String text) async {
    final wrote = await _writeSuperClipboard((item) {
      item.add(Formats.plainText(text));
    });
    if (wrote) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Writes HTML plus a plain-text fallback in one clipboard item.
  Future<void> copyRichText({
    required String html,
    required String plainFallback,
  }) async {
    final wrote = await _writeSuperClipboard((item) {
      item.add(Formats.htmlText(html));
      item.add(Formats.plainText(plainFallback));
    });
    if (wrote) return;
    await Clipboard.setData(ClipboardData(text: plainFallback));
  }

  /// Attempts a `super_clipboard` write. Returns false when the native
  /// clipboard is unavailable (web restrictions, missing plugin, test harness).
  Future<bool> _writeSuperClipboard(
    void Function(DataWriterItem item) populate,
  ) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return false;
      final item = DataWriterItem();
      populate(item);
      await clipboard.write([item]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
