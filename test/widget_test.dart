import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:clean_canvas/main.dart';
import 'package:clean_canvas/features/scratchpad/presentation/scratchpad_screen.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';

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
