import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/theme_settings.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/platform/biometric_service.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/settings_screen.dart';
import 'package:citadel_auth/ui/screens/setup_screen.dart';
import 'package:citadel_auth/ui/theme/palette.dart';

/// In-memory keystore fake covering every read/write the delete and setup
/// flows touch, so the real FlutterSecureStorage platform channel is never
/// hit in tests.
class _FakeKeystoreService extends KeystoreService {
  bool pinEnabled = false;
  bool biometricEnabled = false;
  String? unlockMethod;
  String? masterPassword;
  Uint8List? vaultKey;
  bool clearAllCalled = false;

  @override
  Future<bool> isPinEnabled() async => pinEnabled;

  @override
  Future<void> setPinEnabled(bool enabled) async => pinEnabled = enabled;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricEnabled(bool enabled) async =>
      biometricEnabled = enabled;

  @override
  Future<String> getUnlockMethod() async => unlockMethod ?? 'password';

  @override
  Future<void> setUnlockMethod(String method) async => unlockMethod = method;

  @override
  Future<void> storeMasterPassword(String password) async =>
      masterPassword = password;

  @override
  Future<bool> verifyMasterPassword(String candidate) async =>
      candidate == masterPassword;

  @override
  Future<void> storeVaultKey(Uint8List key) async => vaultKey = key;

  @override
  Future<void> clearAll() async {
    clearAllCalled = true;
    pinEnabled = false;
    biometricEnabled = false;
    unlockMethod = null;
    masterPassword = null;
    vaultKey = null;
  }
}

class _FakeBiometricService extends BiometricService {
  bool available = false;

  @override
  Future<bool> isAvailable() async => available;
}

/// Overrides deleteVault/exists so no real SQLCipher file is ever touched.
class _FakeVaultDatabase extends VaultDatabase {
  bool deleteVaultCalled = false;

  @override
  Future<bool> exists() async => true;

  @override
  Future<void> deleteVault() async => deleteVaultCalled = true;
}

/// Overrides createVault so no real SQLCipher database is ever opened.
class _FakeVaultNotifier extends VaultNotifier {
  _FakeVaultNotifier() : super(VaultDatabase());

  bool createResult = true;
  final createCalls = <String>[];

  @override
  Future<bool> createVault(String passphrase) async {
    createCalls.add(passphrase);
    if (createResult) state = VaultState(VaultStatus.unlocked);
    return createResult;
  }
}

void main() {
  testWidgets(
      'deleting the vault invalidates cached PIN/biometric provider state',
      (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..biometricEnabled = true
      ..unlockMethod = 'biometric'
      ..masterPassword = 'old-master-pw';
    final db = _FakeVaultDatabase();

    final container = ProviderContainer(overrides: [
      keystoreServiceProvider.overrideWithValue(keystore),
      vaultDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    // Prime the caches the way visiting Settings on the old account would.
    expect(await container.read(pinEnabledProvider.future), true);
    expect(await container.read(biometricEnabledProvider.future), true);

    // Simulate the old account having customized its non-security settings
    // too — deleting the vault should forget these as well.
    container.read(autoLockDurationProvider.notifier).state =
        const Duration(minutes: 30);
    container.read(citadelThemeModeProvider.notifier).state = CitadelThemeMode.dark;
    container.read(customThemeColorsProvider.notifier).state = const CustomThemeColors(
      background: Colors.red,
      text: Colors.red,
      element: Colors.red,
    );
    container.read(allViewGeneralSortOrderProvider.notifier).state = 3;

    // Phone-sized surface — the default 800x600 test window cuts off the
    // "Danger Zone" section, which sits far down the settings list.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete Vault'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Delete Vault'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Everything'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'old-master-pw');
    await tester.tap(find.text('Confirm'));
    // Let the async onConfirm handler (deleteVault + clearAll + invalidate)
    // run without pumping through VaultDeletedScreen's timed animation.
    await tester.pump();
    await tester.pump();

    expect(db.deleteVaultCalled, isTrue);
    expect(keystore.clearAllCalled, isTrue);
    // The bug: without invalidating, these would still resolve to the old
    // vault's cached `true` even though the keystore was just wiped.
    expect(await container.read(pinEnabledProvider.future), false);
    expect(await container.read(biometricEnabledProvider.future), false);
    // Same bug, for every other persisted setting: without invalidating
    // them too, the next account would silently inherit the old one's
    // auto-lock timeout, theme, accent color, and Home-screen sort order.
    expect(container.read(autoLockDurationProvider), const Duration(minutes: 5));
    expect(container.read(citadelThemeModeProvider), CitadelThemeMode.system);
    expect(container.read(customThemeColorsProvider).element, Palette.primary);
    expect(container.read(allViewGeneralSortOrderProvider), -1);

    // Drain VaultDeletedScreen's message/logo timers (1400ms each) so none
    // are left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'creating a vault with device lock does not inherit a stale cached '
      'PIN-enabled flag from a previously deleted vault', (tester) async {
    final keystore = _FakeKeystoreService();
    final biometric = _FakeBiometricService()..available = true;
    final vault = _FakeVaultNotifier();

    final container = ProviderContainer(overrides: [
      keystoreServiceProvider.overrideWithValue(keystore),
      biometricServiceProvider.overrideWithValue(biometric),
      vaultProvider.overrideWith((ref) => vault),
    ]);
    addTearDown(container.dispose);

    // Simulate a stale cache primed while a previous account had an app PIN.
    keystore.pinEnabled = true;
    expect(await container.read(pinEnabledProvider.future), true);
    // The vault was since deleted and wiped; the keystore now reflects that,
    // but the provider cache above still holds the stale `true`.
    keystore.pinEnabled = false;

    // Tall surface — the default 800x600 test window (and even a normal
    // phone height) puts "Create Vault" below the visible viewport and
    // fails the tap's hit test.
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SetupScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'new-password');
    await tester.enterText(find.byType(TextField).at(1), 'new-password');
    await tester.tap(find.text("Use my phone's screen lock"));
    await tester.pump();
    await tester.tap(find.text('Create Vault'));
    await tester.pumpAndSettle();

    expect(vault.createCalls, ['new-password']);
    expect(keystore.pinEnabled, false);
    // The bug: without invalidating, this would still resolve to the old
    // vault's cached `true` even though this account never enabled a PIN.
    expect(await container.read(pinEnabledProvider.future), false);
  });
}
