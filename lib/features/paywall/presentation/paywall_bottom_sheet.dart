import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/revenue_cat_config.dart';
import '../../scratchpad/presentation/legal_document_viewer.dart';
import '../services/paywall_service.dart';
import '../state/paywall_providers.dart';

/// CTA copy. Uses the store's localized [Package.storeProduct.priceString]
/// and falls back to `$4.99` when offerings are unavailable.
String unlockLifetimeButtonLabel(Package? package) {
  final price = package?.storeProduct.priceString.trim() ?? '';
  final shown =
      price.isEmpty ? RevenueCatConfig.lifetimePriceLabel : price;
  return 'Unlock Lifetime Pro — $shown';
}

/// High-converting lifetime unlock sheet. Returns `true` when Pro becomes
/// active (purchase or restore), `false` / `null` when dismissed.
class PaywallBottomSheet extends ConsumerStatefulWidget {
  const PaywallBottomSheet({super.key, this.highlightBenefit});

  /// Optional benefit to call out when the sheet is opened from a gated action.
  final String? highlightBenefit;

  static Future<bool?> show(
    BuildContext context, {
    String? highlightBenefit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => PaywallBottomSheet(
        highlightBenefit: highlightBenefit,
      ),
    );
  }

  @override
  ConsumerState<PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends ConsumerState<PaywallBottomSheet> {
  bool _purchasePending = false;
  bool _restorePending = false;
  String? _errorMessage;

  bool get _busy => _purchasePending || _restorePending;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = colors.onSurface;
    final offering = ref.watch(currentOfferingProvider);
    final package = offering.maybeWhen(
      data: selectLifetimePackage,
      orElse: () => null,
    );
    final unlockLabel = unlockLifetimeButtonLabel(package);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unlock PenningPal Pro',
              key: const Key('paywall-headline'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.4,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep unlimited text conversion. Pro unlocks the visuals.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: ink.withValues(alpha: 0.65),
              ),
            ),
            if (widget.highlightBenefit != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    widget.highlightBenefit!,
                    key: const Key('paywall-highlight'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const _BenefitRow(
              icon: Icons.water_drop_outlined,
              label: "Remove 'Made with PenningPal' watermark",
            ),
            const _BenefitRow(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export swipeable LinkedIn PDF carousels',
            ),
            const _BenefitRow(
              icon: Icons.badge_outlined,
              label: 'Unlimited Ghostwriter & Brand profiles',
            ),
            const _BenefitRow(
              icon: Icons.palette_outlined,
              label:
                  'Unlock Aurora, Editorial Cream, Neo-Brutal & Custom Hex themes',
            ),
            const _BenefitRow(
              icon: Icons.photo_outlined,
              label: 'Custom photo backdrops with blur and contrast scrim',
            ),
            const _BenefitRow(
              icon: Icons.font_download_outlined,
              label: 'Curated font pairings and unlimited brand kits',
            ),
            const SizedBox(height: 20),
            Text(
              'One-time purchase · Lifetime access',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: ink.withValues(alpha: 0.6),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                key: const Key('paywall-error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('paywall-unlock'),
              onPressed: _busy ? null : () => _unlock(package),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _purchasePending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(
                        unlockLabel,
                        key: const Key('paywall-price'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('paywall-restore'),
              onPressed: _busy ? null : _restore,
              child: _restorePending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Restore Purchases',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: const Key('paywall-terms'),
                  onPressed: _busy
                      ? null
                      : () => LegalDocumentViewer.showTerms(context),
                  child: Text(
                    'Terms',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
                Text(
                  '·',
                  style: GoogleFonts.inter(
                    color: ink.withValues(alpha: 0.4),
                  ),
                ),
                TextButton(
                  key: const Key('paywall-privacy'),
                  onPressed: _busy
                      ? null
                      : () => LegalDocumentViewer.showPrivacy(context),
                  child: Text(
                    'Privacy',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock(Package? package) async {
    setState(() {
      _purchasePending = true;
      _errorMessage = null;
    });
    try {
      final resolved = package ??
          selectLifetimePackage(
            await ref.read(currentOfferingProvider.future),
          );
      if (resolved == null) {
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _errorMessage =
              'The store is unavailable right now. Please try again.';
        });
        return;
      }
      final unlocked = await ref
          .read(paywallProvider.notifier)
          .purchasePackage(resolved);
      if (!mounted) return;
      setState(() => _purchasePending = false);
      if (unlocked) {
        Navigator.of(context).pop(true);
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      final cancelled = PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError;
      setState(() {
        _purchasePending = false;
        _errorMessage = cancelled
            ? null
            : 'Purchase could not be completed. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _errorMessage = 'Purchase could not be completed. Please try again.';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _restorePending = true;
      _errorMessage = null;
    });
    final restored =
        await ref.read(paywallProvider.notifier).restorePurchases();
    if (!mounted) return;
    setState(() => _restorePending = false);
    if (restored) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errorMessage = 'No Pro purchase was found to restore.';
    });
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
