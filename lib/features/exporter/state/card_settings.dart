import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/settings_storage.dart';

final settingsStorageProvider =
    Provider<SettingsStorage>((ref) => SettingsStorage());

final cardSettingsProvider =
    NotifierProvider<CardSettingsNotifier, CardSettings>(
  CardSettingsNotifier.new,
);

class CardSettingsNotifier extends Notifier<CardSettings> {
  @override
  CardSettings build() {
    return ref.watch(settingsStorageProvider).load();
  }

  Future<void> update({
    String? authorName,
    String? authorHandle,
    int? avatarPreset,
  }) async {
    final next = state.copyWith(
      authorName: authorName,
      authorHandle: authorHandle,
      avatarPreset: avatarPreset,
    );
    state = next;
    await ref.read(settingsStorageProvider).save(next);
  }
}
