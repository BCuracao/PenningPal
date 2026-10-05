import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/brand_kit.dart';
import '../../storage/brand_logo_store.dart';

/// Name and optional logo collected before a kit is written to Hive.
class BrandKitDraft {
  const BrandKitDraft({required this.name, this.logoPath});

  final String name;
  final String? logoPath;
}

/// Horizontal kit switcher plus a Save chip.
class BrandKitCarousel extends StatelessWidget {
  const BrandKitCarousel({
    super.key,
    required this.kits,
    required this.selectedId,
    required this.onSelected,
    required this.onSave,
    required this.onDelete,
    this.enabled = true,
  });

  final List<BrandKit> kits;
  final String? selectedId;
  final ValueChanged<BrandKit> onSelected;
  final VoidCallback onSave;
  final ValueChanged<BrandKit> onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        key: const Key('brand-kit-carousel'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: kits.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SaveKitChip(
              enabled: enabled,
              onTap: onSave,
              foreground: colors.primary,
            );
          }
          final kit = kits[index - 1];
          return _BrandKitChip(
            kit: kit,
            selected: kit.id == selectedId,
            enabled: enabled,
            onTap: () => onSelected(kit),
            onDelete: () => onDelete(kit),
          );
        },
      ),
    );
  }
}

class _SaveKitChip extends StatelessWidget {
  const _SaveKitChip({
    required this.enabled,
    required this.onTap,
    required this.foreground,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        key: const Key('brand-kit-save'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                'Save kit',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandKitChip extends StatelessWidget {
  const _BrandKitChip({
    required this.kit,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final BrandKit kit;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.55)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('brand-kit-${kit.id}'),
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onDelete : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: kit.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: kit.secondary, width: 2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                kit.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a kit name and an optional on-device logo.
class BrandKitSaveSheet extends StatefulWidget {
  const BrandKitSaveSheet({super.key, this.logoStore = const BrandLogoStore()});

  final BrandLogoStore logoStore;

  static Future<BrandKitDraft?> show(
    BuildContext context, {
    BrandLogoStore logoStore = const BrandLogoStore(),
  }) {
    return showModalBottomSheet<BrandKitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => BrandKitSaveSheet(logoStore: logoStore),
    );
  }

  @override
  State<BrandKitSaveSheet> createState() => _BrandKitSaveSheetState();
}

class _BrandKitSaveSheetState extends State<BrandKitSaveSheet> {
  late final TextEditingController _name;
  String? _logoPath;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'Personal Brand');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final path = await widget.logoStore.pickFromGallery();
      if (!mounted || path == null) return;
      setState(() => _logoPath = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that logo')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    Navigator.of(context).pop(
      BrandKitDraft(
        name: name.isEmpty ? 'Personal Brand' : name,
        logoPath: _logoPath,
      ),
    );
  }

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
        key: const Key('brand-kit-save-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save brand kit',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stores the current colors, type, ratio, and an optional logo on this device.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('brand-kit-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Kit name',
              hintText: 'Personal Brand',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('brand-kit-logo'),
            onPressed: _picking ? null : _pickLogo,
            icon: _picking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined, size: 18),
            label: Text(_logoPath == null ? 'Add logo' : 'Logo added'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('brand-kit-confirm'),
            onPressed: _save,
            child: const Text('Save kit'),
          ),
        ],
      ),
    );
  }
}
