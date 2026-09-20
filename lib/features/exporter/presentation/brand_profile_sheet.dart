import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/persistence/profile_storage.dart';
import '../../paywall/paywall_bottom_sheet.dart';
import '../../paywall/paywall_provider.dart';
import '../state/card_settings.dart';

const brandAvatarColors = <Color>[
  Color(0xFF1F2937),
  Color(0xFF0F766E),
  Color(0xFF1D4ED8),
  Color(0xFF7C3AED),
  Color(0xFFB45309),
  Color(0xFFBE123C),
];

/// Switch, add, and delete ghostwriter / brand personas.
class BrandProfileSheet extends ConsumerWidget {
  const BrandProfileSheet({super.key});

  static Future<AuthorProfile?> show(BuildContext context) {
    return showModalBottomSheet<AuthorProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const BrandProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cardSettingsProvider);
    final isProPurchased = ref.watch(isProPurchasedProvider);
    final canAccessPro = ref.watch(canAccessProFeatureProvider);
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('brand-profile-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Brand Profiles',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isProPurchased
                  ? 'Switch ghostwriter identities in one tap.'
                  : 'Free accounts keep 1 profile. Pro unlocks unlimited brands.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            for (final profile in settings.profiles)
              _ProfileTile(
                profile: profile,
                selected: profile.id == settings.activeProfileId,
                canDelete: settings.profiles.length > 1,
                onSelect: () => Navigator.of(context).pop(profile),
                onDelete: () => ref
                    .read(cardSettingsProvider.notifier)
                    .deleteProfile(profile.id),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('add-brand-profile'),
              onPressed: () => _addProfile(context, ref, canAccessPro),
              icon: Icon(
                isProPurchased ||
                        settings.profiles.length <
                            ProfileStorage.freeProfileLimit
                    ? Icons.add
                    : Icons.lock_outline,
                size: 18,
              ),
              label: const Text('+ Add Brand Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProfile(
    BuildContext context,
    WidgetRef ref,
    bool isPro,
  ) async {
    final storage = ref.read(profileStorageProvider);
    if (!storage.canAddProfile(isProPurchased: isPro)) {
      await PaywallBottomSheet.show(
        context,
        highlightBenefit: 'Unlimited Ghostwriter & Brand profiles',
      );
      return;
    }

    final created = await _promptNewProfile(context);
    if (created == null) return;
    final profile = await ref.read(cardSettingsProvider.notifier).addProfile(
          isProPurchased: isPro,
          name: created.name,
          handle: created.handle,
        );
    if (profile == null) {
      if (!context.mounted) return;
      await PaywallBottomSheet.show(
        context,
        highlightBenefit: 'Unlimited Ghostwriter & Brand profiles',
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(profile);
  }

  Future<({String name, String handle})?> _promptNewProfile(
    BuildContext context,
  ) async {
    final name = TextEditingController();
    final handle = TextEditingController();
    final result = await showDialog<({String name, String handle})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('add-brand-profile-dialog'),
          title: const Text('New brand profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('new-profile-name'),
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                key: const Key('new-profile-handle'),
                controller: handle,
                decoration: const InputDecoration(labelText: '@handle'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('new-profile-save'),
              onPressed: () => Navigator.pop(
                context,
                (name: name.text.trim(), handle: handle.text.trim()),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    name.dispose();
    handle.dispose();
    return result;
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.canDelete,
    required this.onSelect,
    required this.onDelete,
  });

  final AuthorProfile profile;
  final bool selected;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatarColor =
        brandAvatarColors[profile.avatarPreset % brandAvatarColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.08)
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          key: Key('brand-profile-${profile.id}'),
          onTap: onSelect,
          leading: CircleAvatar(
            backgroundColor: avatarColor,
            child: Text(
              profile.initials,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            profile.displayName,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: profile.formattedHandle == null
              ? null
              : Text(profile.formattedHandle!),
          trailing: canDelete
              ? IconButton(
                  key: Key('delete-brand-profile-${profile.id}'),
                  tooltip: 'Delete profile',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                )
              : (selected ? Icon(Icons.check, color: colors.primary) : null),
        ),
      ),
    );
  }
}
