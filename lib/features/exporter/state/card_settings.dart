import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/profile_storage.dart';
import '../../../core/persistence/settings_storage.dart';

final settingsStorageProvider =
    Provider<SettingsStorage>((ref) => SettingsStorage());

final profileStorageProvider =
    Provider<ProfileStorage>((ref) => ProfileStorage());

final cardSettingsProvider =
    NotifierProvider<CardSettingsNotifier, CardSettings>(
  CardSettingsNotifier.new,
);

class CardSettingsNotifier extends Notifier<CardSettings> {
  @override
  CardSettings build() {
    final settings = ref.watch(settingsStorageProvider).load();
    final profiles = ref.watch(profileStorageProvider);
    profiles.seedFrom(
      authorName: settings.authorName,
      authorHandle: settings.authorHandle,
      avatarPath: settings.avatarPath,
      defaultFont: settings.defaultFont,
      defaultThemeId: settings.defaultThemeId,
      avatarPreset: settings.avatarPreset,
    );
    return _compose(settings, profiles);
  }

  Future<void> update({
    String? authorName,
    String? authorHandle,
    int? avatarPreset,
    String? avatarPath,
    String? defaultFont,
    String? defaultThemeId,
    int? customBackgroundColor,
    int? customTextColor,
  }) async {
    var next = state.copyWith(
      authorName: authorName,
      authorHandle: authorHandle,
      avatarPreset: avatarPreset,
      avatarPath: avatarPath,
      defaultFont: defaultFont,
      defaultThemeId: defaultThemeId,
      customBackgroundColor: customBackgroundColor,
      customTextColor: customTextColor,
    );
    next = await _persistActiveProfile(next);
    state = next;
    await ref.read(settingsStorageProvider).save(next);
  }

  Future<void> selectProfile(String id) async {
    final storage = ref.read(profileStorageProvider);
    final profile = storage.getProfile(id);
    if (profile == null) return;
    await storage.setActiveId(id);
    final next = state.copyWith(
      authorName: profile.name,
      authorHandle: profile.handle,
      avatarPreset: profile.avatarPreset,
      avatarPath: profile.avatarPath,
      defaultFont: profile.defaultFont,
      defaultThemeId: profile.defaultThemeId,
      activeProfileId: profile.id,
      profiles: storage.listProfiles(),
    );
    state = next;
    await ref.read(settingsStorageProvider).save(next);
  }

  /// Returns the new profile, or `null` when the free-tier cap blocks it.
  Future<AuthorProfile?> addProfile({
    required bool isProPurchased,
    String name = '',
    String handle = '',
    String? defaultThemeId,
    String? defaultFont,
    int? avatarPreset,
  }) async {
    final storage = ref.read(profileStorageProvider);
    if (!storage.canAddProfile(isProPurchased: isProPurchased)) {
      return null;
    }
    try {
      final profile = await storage.createProfile(
        isProPurchased: isProPurchased,
        name: name,
        handle: handle,
        defaultThemeId: defaultThemeId ?? state.defaultThemeId,
        defaultFont: defaultFont ?? state.defaultFont,
        avatarPreset: avatarPreset ?? state.avatarPreset,
      );
      await storage.setActiveId(profile.id);
      final next = state.copyWith(
        authorName: profile.name,
        authorHandle: profile.handle,
        avatarPreset: profile.avatarPreset,
        avatarPath: profile.avatarPath,
        defaultFont: profile.defaultFont,
        defaultThemeId: profile.defaultThemeId,
        activeProfileId: profile.id,
        profiles: storage.listProfiles(),
      );
      state = next;
      await ref.read(settingsStorageProvider).save(next);
      return profile;
    } on ProfileLimitException {
      return null;
    }
  }

  Future<void> deleteProfile(String id) async {
    final storage = ref.read(profileStorageProvider);
    await storage.deleteProfile(id);
    final next = _compose(state, storage);
    state = next;
    await ref.read(settingsStorageProvider).save(next);
  }

  CardSettings _compose(CardSettings settings, ProfileStorage storage) {
    final list = storage.listProfiles();
    final active = storage.getActiveProfile();
    if (active == null) {
      return settings.copyWith(profiles: list);
    }
    return settings.copyWith(
      authorName: active.name,
      authorHandle: active.handle,
      avatarPreset: active.avatarPreset,
      avatarPath: active.avatarPath,
      defaultFont: active.defaultFont,
      defaultThemeId: active.defaultThemeId,
      activeProfileId: active.id,
      profiles: list,
    );
  }

  Future<CardSettings> _persistActiveProfile(CardSettings next) async {
    final storage = ref.read(profileStorageProvider);
    final activeId = next.activeProfileId;
    if (activeId.isEmpty) {
      return next.copyWith(profiles: storage.listProfiles());
    }
    final existing = storage.getProfile(activeId);
    if (existing == null) {
      return next.copyWith(profiles: storage.listProfiles());
    }
    final updated = existing.copyWith(
      name: next.authorName,
      handle: next.authorHandle,
      avatarPath: next.avatarPath,
      defaultFont: next.defaultFont,
      defaultThemeId: next.defaultThemeId,
      avatarPreset: next.avatarPreset,
    );
    await storage.saveProfile(updated);
    return next.copyWith(profiles: storage.listProfiles());
  }
}
