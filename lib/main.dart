import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/persistence/draft_storage.dart';
import 'features/paywall/paywall_provider.dart';
import 'features/paywall/paywall_service.dart';
import 'features/scratchpad/presentation/scratchpad_screen.dart';
import 'features/scratchpad/state/scratchpad_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final drafts = DraftStorage();
  await drafts.init();

  final paywall = PaywallService();
  await paywall.initialize();

  runApp(
    ProviderScope(
      overrides: [
        draftStorageProvider.overrideWithValue(drafts),
        paywallServiceProvider.overrideWithValue(paywall),
      ],
      child: const CleanCanvasApp(),
    ),
  );
}

class CleanCanvasApp extends ConsumerWidget {
  const CleanCanvasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm cached entitlements on launch so offline Pro users keep access.
    ref.watch(paywallProvider);

    const canvas = Color(0xFFFAFAF7);
    const ink = Color(0xFF2C2C2A);

    return MaterialApp(
      title: 'Clean Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
          surface: canvas,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: canvas,
          foregroundColor: ink,
        ),
      ),
      home: const ScratchpadScreen(),
    );
  }
}
