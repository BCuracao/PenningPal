import 'dart:io';

import 'package:clean_canvas/core/persistence/profile_storage.dart';
import 'package:clean_canvas/core/persistence/settings_storage.dart';
import 'package:clean_canvas/features/exporter/presentation/card_exporter_screen.dart';
import 'package:clean_canvas/features/exporter/state/card_settings.dart';
import 'package:clean_canvas/features/paywall/paywall_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../helpers/fake_paywall_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ProfileStorage limits', () {
    test('free users can create one profile and are blocked on the second',
        () async {
      final storage = ProfileStorage();
      expect(storage.canAddProfile(isProPurchased: false), isTrue);

      final first = await storage.createProfile(
        isProPurchased: false,
        name: 'Ada',
        handle: '@ada',
      );
      expect(first.name, 'Ada');
      expect(storage.listProfiles(), hasLength(1));
      expect(storage.canAddProfile(isProPurchased: false), isFalse);

      expect(
        () => storage.createProfile(isProPurchased: false, name: 'Grace'),
        throwsA(isA<ProfileLimitException>()),
      );
      expect(storage.listProfiles(), hasLength(1));
    });

    test('pro users can create multiple brand profiles', () async {
      final storage = ProfileStorage();
      await storage.createProfile(isProPurchased: true, name: 'Client A');
      await storage.createProfile(
        isProPurchased: true,
        name: 'Client B',
        handle: '@ghost',
      );

      final listed = storage.listProfiles();
      expect(listed, hasLength(2));
      expect(listed.map((profile) => profile.name), containsAll(['Client A', 'Client B']));
      expect(storage.canAddProfile(isProPurchased: true), isTrue);
    });

    test('seedFrom only inserts a default profile when the box is empty', () {
      final storage = ProfileStorage();
      storage.seedFrom(authorName: 'Seeded', authorHandle: 'seed');
      storage.seedFrom(authorName: 'Ignored');

      final listed = storage.listProfiles();
      expect(listed, hasLength(1));
      expect(listed.single.name, 'Seeded');
      expect(listed.single.formattedHandle, '@seed');
      expect(storage.getActiveProfile()?.id, listed.single.id);
    });

    test('select, save, and delete round-trip in a Hive box', () async {
      final dir = await Directory.systemTemp.createTemp('penningpal_profiles_');
      Hive.init(dir.path);
      final boxName = 'profiles_box_${dir.hashCode}';
      final box = await Hive.openBox<dynamic>(boxName);
      addTearDown(() async {
        if (box.isOpen) await box.close();
        await Hive.deleteBoxFromDisk(boxName);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      final storage = ProfileStorage.withBox(box);
      final a = await storage.createProfile(isProPurchased: true, name: 'A');
      final b = await storage.createProfile(isProPurchased: true, name: 'B');
      await storage.setActiveId(b.id);
      expect(storage.getActiveProfile()?.id, b.id);

      await storage.saveProfile(b.copyWith(handle: '@b'));
      expect(storage.getProfile(b.id)?.handle, '@b');

      await storage.deleteProfile(b.id);
      expect(storage.listProfiles().map((profile) => profile.id), [a.id]);
      expect(storage.getActiveId(), a.id);
    });

    test('refuses to delete the last remaining profile', () async {
      final storage = ProfileStorage();
      final only = await storage.createProfile(
        isProPurchased: false,
        name: 'Only',
      );
      await storage.deleteProfile(only.id);
      expect(storage.listProfiles(), hasLength(1));
      expect(storage.getProfile(only.id)?.name, 'Only');
    });
  });

  group('cardSettingsProvider profiles', () {
    test('free addProfile returns null after the first persona', () async {
      final profiles = ProfileStorage();
      final settings = SettingsStorage();
      final container = ProviderContainer(
        overrides: [
          profileStorageProvider.overrideWithValue(profiles),
          settingsStorageProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cardSettingsProvider.notifier);
      // Seed inserts the default persona.
      expect(container.read(cardSettingsProvider).profiles, hasLength(1));

      final second = await notifier.addProfile(
        isProPurchased: false,
        name: 'Second',
      );
      expect(second, isNull);
      expect(container.read(cardSettingsProvider).profiles, hasLength(1));
    });

    test('pro addProfile and selectProfile switch the active author', () async {
      final profiles = ProfileStorage();
      final settings = SettingsStorage();
      final container = ProviderContainer(
        overrides: [
          profileStorageProvider.overrideWithValue(profiles),
          settingsStorageProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cardSettingsProvider.notifier);
      final created = await notifier.addProfile(
        isProPurchased: true,
        name: 'Ghostwriter',
        handle: 'ghost',
      );
      expect(created, isNotNull);
      expect(container.read(cardSettingsProvider).authorName, 'Ghostwriter');
      expect(container.read(cardSettingsProvider).formattedHandle, '@ghost');
      expect(container.read(cardSettingsProvider).profiles, hasLength(2));

      final original = container.read(cardSettingsProvider).profiles.firstWhere(
            (profile) => profile.id != created!.id,
          );
      await notifier.selectProfile(original.id);
      expect(container.read(cardSettingsProvider).activeProfileId, original.id);
    });
  });

  group('Brand profile UI', () {
    testWidgets('exporter pill opens the switcher; free add shows the paywall',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paywallServiceProvider.overrideWithValue(FakePaywallService()),
          ],
          child: const MaterialApp(
            home: CardExporterScreen(text: 'A short quote for the card.'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('profile-switcher-pill')), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-switcher-pill')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('brand-profile-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-brand-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Unlock PenningPal Pro'), findsOneWidget);
      expect(
        find.text('Unlimited Ghostwriter & Brand profiles'),
        findsWidgets,
      );
    });
  });
}
