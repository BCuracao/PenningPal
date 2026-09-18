import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/revenue_cat_config.dart';
import 'paywall_provider.dart';

/// High-converting lifetime unlock sheet. Returns `true` when Pro becomes
/// active (purchase or restore), `false` / `null` when dismissed.
class PaywallBottomSheet extends ConsumerStatefulWidget {
  const PaywallBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const PaywallBottomSheet(),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unlock SocialSlate Pro',
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
          const SizedBox(height: 20),
          const _BenefitRow(
            icon: Icons.water_drop_outlined,
            label: 'Remove card watermarks',
          ),
          const _BenefitRow(
            icon: Icons.dark_mode_outlined,
            label: 'Access midnight and terminal themes',
          ),
          const _BenefitRow(
            icon: Icons.text_fields_outlined,
            label: 'Unlock custom typography',
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'One-time payment of ${RevenueCatConfig.lifetimePriceLabel} (Lifetime Access)',
                key: const Key('paywall-price'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: ink,
                ),
              ),
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
            onPressed: _busy ? null : _unlock,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _purchasePending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(
                      'Unlock Lifetime Pro',
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
                    : () => _openLegal(RevenueCatConfig.termsOfUseUrl),
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
                    : () => _openLegal(RevenueCatConfig.privacyPolicyUrl),
                child: Text(
                  'Privacy',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() {
      _purchasePending = true;
      _errorMessage = null;
    });
    final unlocked =
        await ref.read(paywallProvider.notifier).purchaseLifetime();
    if (!mounted) return;
    setState(() => _purchasePending = false);
    if (unlocked) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errorMessage = 'Purchase was cancelled or could not be completed.';
    });
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

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Legal links are required on the sheet even if the OS cannot open them.
    }
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
