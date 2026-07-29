import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/platform/biometric_service.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/settings_screen.dart';

/// In-memory keystore fake covering every read/write the Biometric Unlock
/// toggle touches, so the real FlutterSecureStorage platform channel is
/// never hit in tests.
class _FakeKeystoreService extends KeystoreService {
  bool pinEnabled = false;
  bool biometricEnabled = false;
  String? unlockMethod;
  String? masterPassword;
  Uint8List? vaultKey;

  @override
  Future<bool> isPinEnabled() async => pinEnabled;

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
}

class _FakeBiometricService extends BiometricService {
  bool available = false;
  // Defaults to [available] unless a test wants to model a device that has
  // *a* screen lock (isAvailable) but no real fingerprint/face sensor.
  bool? hasHardware;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasBiometricHardware() async => hasHardware ?? available;
}

/// Overrides verifyPassphrase so no real SQLCipher file is ever touched.
class _FakeVaultDatabase extends VaultDatabase {
  String? correctPassphrase;

  @override
  Future<bool> verifyPassphrase(String passphrase) async =>
      passphrase == correctPassphrase;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required _FakeKeystoreService keystore,
  required _FakeBiometricService biometric,
  required _FakeVaultDatabase db,
}) async {
  final container = ProviderContainer(overrides: [
    keystoreServiceProvider.overrideWithValue(keystore),
    biometricServiceProvider.overrideWithValue(biometric),
    vaultDatabaseProvider.overrideWithValue(db),
  ]);
  addTearDown(container.dispose);

  // Phone-sized surface so the Security section and its switch aren't
  // clipped by the default 800x600 test window.
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
}

/// Bounded alternative to pumpAndSettle(). While the toggle's async chain is
/// in flight, the tile shows an indeterminate CircularProgressIndicator,
/// which schedules frames forever and makes plain pumpAndSettle() time out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _enterPinAndConfirm(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.tap(find.text('Confirm'));
  await _settle(tester);
}

void main() {
  testWidgets(
      'enabling biometric unlock for a PIN account re-derives and stores '
      'the vault key instead of just flipping a flag', (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..masterPassword = 'master-pw';
    final biometric = _FakeBiometricService()..available = true;
    final db = _FakeVaultDatabase()..correctPassphrase = 'master-pw112233';

    await _pumpSettings(tester, keystore: keystore, biometric: biometric, db: db);

    // Biometric starts off — the switch is interactive even though this
    // account already has a PIN and never enabled it at setup.
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);

    await tester.tap(find.byType(Switch));
    await _settle(tester);

    // Master password re-entry dialog.
    await tester.enterText(find.byType(TextField), 'master-pw');
    await tester.tap(find.text('Confirm'));
    await _settle(tester);

    // PIN re-entry screen — the PIN is never stored, so it has to be
    // re-confirmed to rebuild the exact passphrase the vault uses.
    expect(find.text('Confirm PIN'), findsWidgets);
    await _enterPinAndConfirm(tester, '112233');

    expect(keystore.biometricEnabled, true);
    expect(keystore.unlockMethod, 'biometric');
    // The bug: previously nothing stored a vault key here at all, so the
    // lock screen's biometric flow would fail with "unavailable" the first
    // time the user actually tried to use it.
    expect(keystore.vaultKey, utf8.encode('master-pw112233'));
  });

  testWidgets(
      'enabling biometric unlock for an account with no PIN works instead '
      'of being permanently blocked', (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = false
      ..masterPassword = 'master-pw';
    final biometric = _FakeBiometricService()..available = true;
    final db = _FakeVaultDatabase();

    await _pumpSettings(tester, keystore: keystore, biometric: biometric, db: db);

    // The bug: this tile used to hard-disable itself and show "Set up an
    // app PIN..." whenever there was no PIN, with no way to ever turn
    // biometric on for such an account.
    expect(find.textContaining('Set up an app PIN'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);

    await tester.tap(find.byType(Switch));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'master-pw');
    await tester.tap(find.text('Confirm'));
    await _settle(tester);

    // No PIN on this account, so there's no PIN re-entry step — the master
    // password alone is the vault's encryption passphrase.
    expect(find.text('Confirm PIN'), findsNothing);
    expect(keystore.biometricEnabled, true);
    expect(keystore.unlockMethod, 'deviceCredential');
    expect(keystore.vaultKey, utf8.encode('master-pw'));
  });

  testWidgets(
      'a PIN account cannot enable biometric unlock on a device that only '
      'has a plain screen lock, no real biometric sensor', (tester) async {
    // The bug: the toggle used to accept isAvailable() (true for *any*
    // secure lock screen, including a bare PIN/pattern) as proof biometrics
    // work, letting a PIN account end up with unlockMethod == 'biometric' on
    // hardware that can never actually satisfy it.
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..masterPassword = 'master-pw';
    final biometric = _FakeBiometricService()
      ..available = true
      ..hasHardware = false;
    final db = _FakeVaultDatabase();

    await _pumpSettings(tester, keystore: keystore, biometric: biometric, db: db);

    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.text('Biometrics not available on this device'), findsOneWidget);
    expect(keystore.biometricEnabled, false);
    expect(keystore.unlockMethod, isNull);
  });

  testWidgets(
      'disabling biometric unlock for an account with no PIN falls back to '
      'password, not the nonexistent PIN', (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = false
      ..biometricEnabled = true
      ..unlockMethod = 'deviceCredential';
    final biometric = _FakeBiometricService()..available = true;
    final db = _FakeVaultDatabase();

    await _pumpSettings(tester, keystore: keystore, biometric: biometric, db: db);

    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(keystore.biometricEnabled, false);
    // The bug: this used to be hardcoded to 'pin' regardless of whether a
    // PIN actually existed on the account.
    expect(keystore.unlockMethod, 'password');
  });
}
