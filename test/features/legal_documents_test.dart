import 'dart:io';

import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:clean_canvas/features/scratchpad/presentation/legal_document_viewer.dart';
import 'package:clean_canvas/features/scratchpad/presentation/settings_bottom_sheet.dart';
import 'package:clean_canvas/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('bundled legal assets', () {
    String readLegal(String name) =>
        File('assets/legal/$name').readAsStringSync();

    test('privacy policy is local and forbids server collection', () {
      final policy = readLegal('privacy_policy.md');
      expect(policy, contains('100% offline'));
      expect(policy.toLowerCase(), contains('no account registration'));
      expect(policy, contains('Hive'));
      expect(policy.toLowerCase(), contains('zero telemetry'));
      expect(policy.toLowerCase(), contains('analytics'));
      expect(policy, contains('RevenueCat'));
      expect(policy, contains('physical device'));
      expect(policy, isNot(contains('https://')));
    });

    test('terms cover the lifetime unlock and limit liability', () {
      final terms = readLegal('terms_of_service.md');
      expect(terms, contains(r'$4.99'));
      expect(terms.toLowerCase(), contains('one-time'));
      expect(terms.toLowerCase(), contains('non-consumable'));
      expect(terms.toLowerCase(), contains('lifetime'));
      expect(terms.toLowerCase(), contains('limitation of liability'));
      expect(terms.toLowerCase(), contains('offline'));
    });
  });

  group('LegalDocumentViewer', () {
    testWidgets('renders the bundled privacy policy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalDocumentViewer(
            title: 'Privacy Policy',
            assetPath: LegalDocumentViewer.privacyAsset,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('legal-document-viewer')), findsOneWidget);
      expect(find.byKey(const Key('legal-document-markdown')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('legal-document-title'))).data,
        'Privacy Policy',
      );
      expect(find.textContaining('100% offline'), findsWidgets);
    });

    testWidgets('renders the bundled terms of service', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalDocumentViewer(
            title: 'Terms of Service',
            assetPath: LegalDocumentViewer.termsAsset,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('legal-document-title'))).data,
        'Terms of Service',
      );
      expect(find.byKey(const Key('legal-document-markdown')), findsOneWidget);
      expect(find.textContaining('These terms govern'), findsWidgets);
    });
  });

  group('Settings legal links', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SettingsBottomSheet()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Privacy Policy opens the in-app document viewer', (tester) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.byKey(const Key('settings-privacy')));
      await tester.tap(find.byKey(const Key('settings-privacy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LegalDocumentViewer), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('legal-document-title'))).data,
        'Privacy Policy',
      );
    });

    testWidgets('Terms of Service opens the in-app document viewer', (tester) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.byKey(const Key('settings-terms')));
      await tester.tap(find.byKey(const Key('settings-terms')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LegalDocumentViewer), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('legal-document-title'))).data,
        'Terms of Service',
      );
    });
  });

  group('store identity', () {
    testWidgets('MaterialApp uses the PenningPal display name', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(
              FakePaywallService(hasProAccess: false),
            ),
          ],
          child: const CleanCanvasApp(),
        ),
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'PenningPal');
    });
  });
}
