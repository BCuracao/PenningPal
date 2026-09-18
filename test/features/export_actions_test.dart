import 'package:clean_canvas/core/clipboard/clipboard_service.dart';
import 'package:clean_canvas/core/converter/html_engine.dart';
import 'package:clean_canvas/core/converter/unicode_engine.dart';
import 'package:clean_canvas/core/persistence/draft_storage.dart';
import 'package:clean_canvas/features/exporter/presentation/card_canvas.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:clean_canvas/features/scratchpad/presentation/export_actions.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/scratchpad/state/scratchpad_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_paywall_service.dart';

class RecordingClipboardService extends ClipboardService {
  final List<String> plainTexts = <String>[];
  final List<({String html, String plainFallback})> richTexts =
      <({String html, String plainFallback})>[];

  @override
  Future<void> copyPlainText(String text) async {
    plainTexts.add(text);
  }

  @override
  Future<void> copyRichText({
    required String html,
    required String plainFallback,
  }) async {
    richTexts.add((html: html, plainFallback: plainFallback));
  }
}

const _draft = '**Hello** world\n- item';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PlatformExporter', () {
    late RecordingClipboardService clipboard;
    late PlatformExporter exporter;
    const unicode = UnicodeEngine();
    const html = HtmlEngine();

    setUp(() {
      clipboard = RecordingClipboardService();
      exporter = PlatformExporter(clipboard: clipboard);
    });

    test('empty and whitespace drafts are ignored', () async {
      expect(await exporter.copyForLinkedIn(''), isFalse);
      expect(await exporter.copyForX('   \n\t'), isFalse);
      expect(await exporter.copyForSubstack(''), isFalse);
      expect(clipboard.plainTexts, isEmpty);
      expect(clipboard.richTexts, isEmpty);
    });

    test('LinkedIn / X / Threads write unicode social plain text', () async {
      expect(await exporter.copyForLinkedIn(_draft), isTrue);
      expect(await exporter.copyForX(_draft), isTrue);
      expect(await exporter.copyForThreads(_draft), isTrue);

      final converted = unicode.convertForSocial(_draft);
      expect(clipboard.plainTexts, [converted, converted, converted]);
      expect(clipboard.richTexts, isEmpty);
    });

    test('Substack writes HTML plus a stripped plain fallback', () async {
      expect(await exporter.copyForSubstack(_draft), isTrue);
      expect(clipboard.plainTexts, isEmpty);
      expect(clipboard.richTexts, hasLength(1));
      expect(clipboard.richTexts.single.html, html.markdownToHtml(_draft));
      expect(
        clipboard.richTexts.single.plainFallback,
        html.markdownToPlain(_draft),
      );
    });

    test('conversion never mutates the source markdown string', () async {
      var source = _draft;
      await exporter.copyForLinkedIn(source);
      await exporter.copyForSubstack(source);
      expect(source, _draft);
    });
  });

  group('ExportToolbar', () {
    late RecordingClipboardService clipboard;

    setUp(() {
      clipboard = RecordingClipboardService();
    });

    Future<void> pumpScratchpad(
      WidgetTester tester, {
      String draft = '',
    }) async {
      final storage = DraftStorage();
      if (draft.isNotEmpty) {
        await storage.createDraft(initialContent: draft);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageProvider.overrideWithValue(storage),
            clipboardServiceProvider.overrideWithValue(clipboard),
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: true),
            ),
          ],
          child: const MaterialApp(home: ScratchpadScreen()),
        ),
      );
      await tester.pump();
    }

    String fieldText(WidgetTester tester) {
      final field = tester.widget<TextField>(
        find.byKey(const Key('scratchpad-field')),
      );
      return field.controller!.text;
    }

    testWidgets('empty draft ignores copy taps without crashing', (
      tester,
    ) async {
      await pumpScratchpad(tester);

      await tester.tap(find.byKey(const Key('export-linkedin')));
      await tester.tap(find.byKey(const Key('export-x-threads')));
      await tester.tap(find.byKey(const Key('export-substack')));
      await tester.pump();

      expect(clipboard.plainTexts, isEmpty);
      expect(clipboard.richTexts, isEmpty);
      expect(find.byKey(const Key('export-copy-x')), findsNothing);
      expect(find.text(ExportMessages.linkedIn), findsNothing);
    });

    testWidgets('LinkedIn copies unicode social text and leaves the draft', (
      tester,
    ) async {
      await pumpScratchpad(tester, draft: _draft);

      await tester.tap(find.byKey(const Key('export-linkedin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        clipboard.plainTexts,
        [const UnicodeEngine().convertForSocial(_draft)],
      );
      expect(clipboard.richTexts, isEmpty);
      expect(fieldText(tester), _draft);
      expect(find.text(ExportMessages.linkedIn), findsOneWidget);
    });

    testWidgets('X copies unicode social text from the platform sheet', (
      tester,
    ) async {
      await pumpScratchpad(tester, draft: _draft);

      await tester.tap(find.byKey(const Key('export-x-threads')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('export-copy-x')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        clipboard.plainTexts,
        [const UnicodeEngine().convertForSocial(_draft)],
      );
      expect(fieldText(tester), _draft);
      expect(find.text(ExportMessages.x), findsOneWidget);
    });

    testWidgets('Threads copies unicode social text from the platform sheet', (
      tester,
    ) async {
      await pumpScratchpad(tester, draft: _draft);

      await tester.tap(find.byKey(const Key('export-x-threads')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('export-copy-threads')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        clipboard.plainTexts,
        [const UnicodeEngine().convertForSocial(_draft)],
      );
      expect(fieldText(tester), _draft);
      expect(find.text(ExportMessages.threads), findsOneWidget);
    });

    testWidgets('Substack copies dual MIME rich text and leaves the draft', (
      tester,
    ) async {
      await pumpScratchpad(tester, draft: _draft);
      const html = HtmlEngine();

      await tester.tap(find.byKey(const Key('export-substack')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(clipboard.plainTexts, isEmpty);
      expect(clipboard.richTexts, hasLength(1));
      expect(clipboard.richTexts.single.html, html.markdownToHtml(_draft));
      expect(
        clipboard.richTexts.single.plainFallback,
        html.markdownToPlain(_draft),
      );
      expect(fieldText(tester), _draft);
      expect(find.text(ExportMessages.substack), findsOneWidget);
    });

    testWidgets('Card opens the exporter with the current draft', (tester) async {
      await pumpScratchpad(tester, draft: _draft);

      await tester.tap(find.byKey(const Key('export-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CardExporterScreen), findsOneWidget);
      expect(find.byKey(const Key('card-canvas')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CardCanvas),
          matching: find.textContaining('Hello'),
        ),
        findsOneWidget,
      );
      expect(find.text('Share Image'), findsOneWidget);
      expect(find.text('Save Image'), findsOneWidget);
    });

    testWidgets('amber indicator appears when the draft exceeds the X limit', (
      tester,
    ) async {
      await pumpScratchpad(tester);
      expect(find.byKey(const Key('x-limit-indicator')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('scratchpad-field')),
        'a' * (PlatformExporter.xCharLimit + 1),
      );
      await tester.pump();

      expect(find.byKey(const Key('x-limit-indicator')), findsOneWidget);
    });
  });
}
