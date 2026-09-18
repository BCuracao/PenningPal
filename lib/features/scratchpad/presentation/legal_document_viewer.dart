import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders a bundled markdown legal document in a modal sheet.
///
/// Documents live in `assets/legal/` so store compliance pages work fully
/// offline — no hosted privacy/terms URL is required.
class LegalDocumentViewer extends StatelessWidget {
  const LegalDocumentViewer({
    super.key,
    required this.title,
    required this.assetPath,
  });

  static const String privacyAsset = 'assets/legal/privacy_policy.md';
  static const String termsAsset = 'assets/legal/terms_of_service.md';

  final String title;
  final String assetPath;

  static Future<void> showPrivacy(BuildContext context) {
    return show(
      context,
      title: 'Privacy Policy',
      assetPath: privacyAsset,
    );
  }

  static Future<void> showTerms(BuildContext context) {
    return show(
      context,
      title: 'Terms of Service',
      assetPath: termsAsset,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => LegalDocumentViewer(
        title: title,
        assetPath: assetPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      key: const Key('legal-document-viewer'),
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      key: const Key('legal-document-title'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('legal-document-close'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: rootBundle.loadString(assetPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'This document is bundled with the app and could not be loaded.',
                          key: const Key('legal-document-error'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }
                  return Markdown(
                    key: const Key('legal-document-markdown'),
                    data: snapshot.data!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: GoogleFonts.inter(fontSize: 15, height: 1.5),
                      h1: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                      h2: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
