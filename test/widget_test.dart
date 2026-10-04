import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:penningpal/main.dart';
import 'package:penningpal/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:penningpal/features/paywall/paywall_provider.dart';

import 'helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots to ScratchpadScreen', (WidgetTester tester) async {
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

    expect(find.byType(ScratchpadScreen), findsOneWidget);
  });
}
