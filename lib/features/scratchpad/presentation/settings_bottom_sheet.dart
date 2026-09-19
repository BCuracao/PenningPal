import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../exporter/presentation/brand_profile_sheet.dart';
import '../../exporter/state/card_settings.dart';
import '../../paywall/paywall_bottom_sheet.dart';
import '../../paywall/paywall_provider.dart';
import 'legal_document_viewer.dart';

const _avatarColors = <Color>[
  Color(0xFF1F2937),
  Color(0xFF0F766E),
  Color(0xFF1D4ED8),
  Color(0xFF7C3AED),
  Color(0xFFB45309),
  Color(0xFFBE123C),
];

/// App settings: default author profile, subscription, restore, legal.
class SettingsBottomSheet extends ConsumerStatefulWidget {
  const SettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const SettingsBottomSheet(),
    );
  }

  @override
  ConsumerState<SettingsBottomSheet> createState() =>
      _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends ConsumerState<SettingsBottomSheet> {
  late final TextEditingController _name;
  late final TextEditingController _handle;
  bool _restorePending = false;
  String? _restoreMessage;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(cardSettingsProvider);
    _name = TextEditingController(text: settings.authorName);
    _handle = TextEditingController(text: settings.authorHandle);
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(cardSettingsProvider);
    final isPro = ref.watch(isProPurchasedProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('settings-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Settings & Profile',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Default Author Profile',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  key: const Key('settings-avatar'),
                  radius: 28,
                  backgroundColor: _avatarColors[settings.avatarPreset],
                  child: Text(
                    settings.initials,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _avatarColors.length; i++)
                        _AvatarShortcut(
                          color: _avatarColors[i],
                          selected: settings.avatarPreset == i,
                          onTap: () => ref
                              .read(cardSettingsProvider.notifier)
                              .update(avatarPreset: i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('settings-author-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => ref
                  .read(cardSettingsProvider.notifier)
                  .update(authorName: value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('settings-author-handle'),
              controller: _handle,
              decoration: const InputDecoration(
                labelText: '@handle',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => ref
                  .read(cardSettingsProvider.notifier)
                  .update(authorHandle: value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('settings-add-brand-profile'),
              onPressed: () => BrandProfileSheet.show(context),
              icon: Icon(
                isPro ? Icons.badge_outlined : Icons.lock_outline,
                size: 18,
              ),
              label: const Text('Brand profiles'),
            ),
            const SizedBox(height: 24),
            Text(
              'Subscription',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            if (isPro)
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  key: const Key('settings-pro-badge'),
                  avatar: Icon(
                    Icons.verified,
                    size: 18,
                    color: colors.primary,
                  ),
                  label: Text(
                    'Pro Active',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              FilledButton.tonal(
                key: const Key('settings-unlock-pro'),
                onPressed: () => PaywallBottomSheet.show(context),
                child: const Text('Unlock PenningPal Pro'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('settings-restore'),
              onPressed: _restorePending ? null : _restore,
              child: _restorePending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore Purchases'),
            ),
            if (_restoreMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _restoreMessage!,
                key: const Key('settings-restore-message'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Legal & About',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            ListTile(
              key: const Key('settings-terms'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right, size: 22),
              onTap: () => LegalDocumentViewer.showTerms(context),
            ),
            ListTile(
              key: const Key('settings-privacy'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right, size: 22),
              onTap: () => LegalDocumentViewer.showPrivacy(context),
            ),
            const SizedBox(height: 4),
            Text(
              'PenningPal 1.0.0',
              key: const Key('settings-version'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore() async {
    setState(() {
      _restorePending = true;
      _restoreMessage = null;
    });
    final restored =
        await ref.read(paywallProvider.notifier).restorePurchases();
    if (!mounted) return;
    setState(() {
      _restorePending = false;
      _restoreMessage = restored
          ? 'Purchases restored. Pro is active.'
          : 'No Pro purchase was found to restore.';
    });
  }
}

class _AvatarShortcut extends StatelessWidget {
  const _AvatarShortcut({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : color,
            width: selected ? 2.5 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
