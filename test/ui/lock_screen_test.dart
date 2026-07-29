import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/platform/biometric_service.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/lock_screen.dart';
import 'package:citadel_auth/ui/widgets/pin_input.dart';

/// In-memory keystore fake — overrides every method the lock screen touches so
/// the real FlutterSecureStorage platform channel is never hit in tests.
class _FakeKeystoreService extends KeystoreService {
  bool pinEnabled = false;
  bool biometricEnabled = false;
  // When unset, mirrors the real migration inference in KeystoreService so
  // existing pinEnabled/biometricEnabled-only setups keep behaving the same.
  String? unlockMethod;
  Uint8List? vaultKey;
  String? masterPassword;
  int pinAttempts = 0;
  DateTime? lockoutUntil;
  String? storedMasterPassword;

  @override
  Future<bool> isPinEnabled() async => pinEnabled;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<String> getUnlockMethod() async {
    if (unlockMethod != null) return unlockMethod!;
    if (pinEnabled && biometricEnabled) return 'biometric';
    if (pinEnabled) return 'pin';
    if (biometricEnabled) return 'deviceCredential';
    return 'password';
  }

  @override
  Future<Uint8List?> getVaultKey() async => vaultKey;

  @override
  Future<String?> getMasterPassword() async => masterPassword;

  @override
  Future<int> getPinAttempts() async => pinAttempts;

  @override
  Future<void> setPinAttempts(int attempts) async => pinAttempts = attempts;

  @override
  Future<DateTime?> getPinLockoutUntil() async => lockoutUntil;

  @override
  Future<void> setPinLockoutUntil(DateTime? until) async => lockoutUntil = until;

  @override
  Future<void> resetPinLockout() async {
    pinAttempts = 0;
    lockoutUntil = null;
  }

  @override
  Future<void> storeMasterPassword(String password) async =>
      storedMasterPassword = password;
}

class _FakeBiometricService extends BiometricService {
  bool available = false;
  bool authenticateResult = false;
  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasBiometricHardware() async => available;

  @override
  Future<bool> authenticate({String reason = 'Unlock Citadel Auth'}) async {
    authenticateCalls++;
    return authenticateResult;
  }
}

/// Overrides unlock so no SQLCipher database is ever opened. The base-class
/// VaultDatabase is only constructed, never used.
class _FakeVaultNotifier extends VaultNotifier {
  _FakeVaultNotifier() : super(VaultDatabase());

  bool unlockResult = false;
  final unlockCalls = <String>[];

  @override
  Future<bool> unlock(String passphrase) async {
    unlockCalls.add(passphrase);
    if (unlockResult) state = VaultState(VaultStatus.unlocked);
    return unlockResult;
  }
}

Future<void> _pumpLockScreen(
  WidgetTester tester, {
  required _FakeKeystoreService keystore,
  required _FakeBiometricService biometric,
  required _FakeVaultNotifier vault,
  Size physicalSize = const Size(1170, 2532),
}) async {
  // Phone-sized surface by default — the PIN keypad plus footer overflows the
  // default 800x600 test window and would fail with a RenderFlex overflow.
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keystoreServiceProvider.overrideWithValue(keystore),
        biometricServiceProvider.overrideWithValue(biometric),
        vaultProvider.overrideWith((ref) => vault),
      ],
      child: const MaterialApp(home: LockScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PIN enabled shows PIN view without a password field',
      (tester) async {
    final keystore = _FakeKeystoreService()..pinEnabled = true;
    final biometric = _FakeBiometricService();
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(find.byType(PinInput), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Biometrics is not usable, so no retry button next to the keypad.
    expect(find.text('Use biometrics'), findsNothing);
    // No password fallback with a PIN enabled: the vault passphrase is
    // password+PIN, and a free-form field would bypass the PIN lockout.
    expect(find.text('Use master password'), findsNothing);
  });

  testWidgets(
      'biometric flag enabled without PIN infers device-lock and shows the '
      'device-credential view, fallback link goes to password', (tester) async {
    // No PIN + the biometric flag is exactly what a "phone's screen lock"
    // setup persists (see KeystoreService.getUnlockMethod migration) — it
    // must NOT render the fingerprint-icon biometric view, since that flow
    // may end up being a PIN/pattern prompt rather than a sensor scan.
    final keystore = _FakeKeystoreService()..biometricEnabled = true;
    final biometric = _FakeBiometricService()..available = true;
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    // Auto-prompt fired once on init; the fake cancelled it, leaving the
    // device-credential primary view on screen.
    expect(biometric.authenticateCalls, 1);
    expect(find.text('Confirm using your device screen lock'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PinInput), findsNothing);
    expect(find.text('Use PIN'), findsNothing);

    await tester.tap(find.text('Use master password'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // The password form offers a way back to the primary method.
    expect(find.text('Use device screen lock'), findsOneWidget);
  });

  testWidgets(
      'unlockMethod=biometric without PIN shows the true biometric view',
      (tester) async {
    // A user could in principle end up here (real biometric, no PIN) only
    // via the explicit unlockMethod flag — the flag combination alone
    // (biometricEnabled + !pinEnabled) always means device-lock. This test
    // exercises the biometric view itself using that explicit flag.
    final keystore = _FakeKeystoreService()
      ..biometricEnabled = true
      ..unlockMethod = 'biometric';
    final biometric = _FakeBiometricService()..available = true;
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(biometric.authenticateCalls, 1);
    expect(find.text('Touch the sensor to unlock'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
  });

  testWidgets('biometric and PIN both enabled: biometric primary, fallback to PIN',
      (tester) async {
    final keystore = _FakeKeystoreService()
      ..biometricEnabled = true
      ..pinEnabled = true;
    final biometric = _FakeBiometricService()..available = true;
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(find.text('Touch the sensor to unlock'), findsOneWidget);
    expect(find.text('Use PIN'), findsOneWidget);
    expect(find.text('Use master password'), findsNothing);

    await tester.tap(find.text('Use PIN'));
    await tester.pumpAndSettle();

    expect(find.byType(PinInput), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // The PIN view offers a way back to biometrics but never to the password
    // form — that would let password+guess attempts bypass the PIN lockout.
    expect(find.text('Use biometrics'), findsOneWidget);
    expect(find.text('Use master password'), findsNothing);
  });

  testWidgets('biometric enabled but unavailable falls back at init',
      (tester) async {
    // unlockMethod explicitly 'biometric' (true fingerprint/face, as opposed
    // to 'deviceCredential' which is trusted unconditionally — see the next
    // test) with no real biometric hardware on the device.
    final keystore = _FakeKeystoreService()
      ..biometricEnabled = true
      ..unlockMethod = 'biometric';
    final biometric = _FakeBiometricService(); // available = false
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(biometric.authenticateCalls, 0);
    expect(find.text('Touch the sensor to unlock'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'PIN+biometric account with no real biometric hardware goes straight '
      'to the PIN view instead of flashing the fingerprint view',
      (tester) async {
    // The bug: isAvailable() (used for both "biometric" and "device
    // credential") is satisfied by a bare PIN/pattern screen lock with no
    // biometric sensor at all, so an account could end up with
    // unlockMethod == 'biometric' and still show/auto-trigger the true
    // fingerprint view on a phone that has no fingerprint sensor.
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..biometricEnabled = true
      ..unlockMethod = 'biometric'
      ..masterPassword = 'master-pw';
    final biometric = _FakeBiometricService(); // available = false
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(biometric.authenticateCalls, 0);
    expect(find.text('Touch the sensor to unlock'), findsNothing);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(find.byType(PinInput), findsOneWidget);
  });

  testWidgets(
      'device-credential accounts always get the screen-lock view and an '
      'auto-prompt, even when a live availability check would say no',
      (tester) async {
    // The bug: a device-lock account (no app PIN, "use my phone's screen
    // lock") used to re-check availability at unlock time and, if that came
    // back false for any reason, silently dropped the user straight onto the
    // bare master-password view with no way back to the screen-lock option
    // at all. Device credential just needs *some* secure lock screen — the
    // same check setup already passed — so it's trusted here instead.
    final keystore = _FakeKeystoreService()
      ..biometricEnabled = true
      ..unlockMethod = 'deviceCredential';
    final biometric = _FakeBiometricService(); // available = false
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    // Still auto-prompts via the OS (which may itself fall back to a PIN/
    // pattern entry) rather than skipping straight to the password form.
    expect(biometric.authenticateCalls, 1);
    expect(find.text('Confirm using your device screen lock'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // And the password fallback is still one tap away from there.
    await tester.tap(find.text('Use master password'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Use device screen lock'), findsOneWidget);
  });

  testWidgets(
      'password-primary account with a leftover vault key still offers '
      'device screen lock as a fallback, and it actually unlocks',
      (tester) async {
    // The bug: turning off "Biometric Unlock" in Settings for a no-PIN
    // account sets unlockMethod to 'password' but does NOT clear the stored
    // vault key — the device's screen lock still works to unlock this vault.
    // Losing the fallback link here stranded the user on password-only with
    // no way back to it.
    final keystore = _FakeKeystoreService()
      ..unlockMethod = 'password'
      ..vaultKey = Uint8List.fromList(utf8.encode('master-pw'));
    final biometric = _FakeBiometricService()
      ..available = true
      ..authenticateResult = true;
    final vault = _FakeVaultNotifier()..unlockResult = true;

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    // Password is primary, so no auto-prompt on init...
    expect(biometric.authenticateCalls, 0);
    expect(find.byType(TextField), findsOneWidget);
    // ...but the screen-lock option is still offered and works.
    expect(find.text('Use device screen lock'), findsOneWidget);

    await tester.tap(find.text('Use device screen lock'));
    await tester.pumpAndSettle();

    expect(biometric.authenticateCalls, 1);
    expect(vault.unlockCalls, ['master-pw']);
  });

  testWidgets('nothing enabled shows master password view', (tester) async {
    final keystore = _FakeKeystoreService();
    final biometric = _FakeBiometricService();
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.byType(PinInput), findsNothing);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    // Password IS the primary method — no switch links at all.
    expect(find.text('Use PIN'), findsNothing);
    expect(find.text('Use biometrics'), findsNothing);
  });

  testWidgets('wrong PIN increments the persisted attempt counter',
      (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..masterPassword = 'master-pw';
    final biometric = _FakeBiometricService();
    final vault = _FakeVaultNotifier(); // unlock always fails

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    await _enterPin(tester, '123456');

    // PIN unlock passphrase is masterPassword + pin.
    expect(vault.unlockCalls, ['master-pw123456']);
    expect(keystore.pinAttempts, 1);
    // Below the lockout threshold: an attempts-left warning, no lockout set.
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(find.textContaining('4 attempt(s) left'), findsOneWidget);
    expect(keystore.lockoutUntil, isNull);
  });

  testWidgets('active lockout blocks PIN attempts and shows the message',
      (tester) async {
    final keystore = _FakeKeystoreService()
      ..pinEnabled = true
      ..masterPassword = 'master-pw'
      ..lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
    final biometric = _FakeBiometricService();
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    await _enterPin(tester, '123456');

    expect(find.textContaining('Too many attempts. Try again in'),
        findsOneWidget);
    // A locked-out entry never reaches the vault or the attempt counter.
    expect(vault.unlockCalls, isEmpty);
    expect(keystore.pinAttempts, 0);
  });

  testWidgets(
      'successful scan with a stale vault key shows an error on the '
      'device-credential view instead of failing silently', (tester) async {
    final keystore = _FakeKeystoreService()
      ..biometricEnabled = true
      // Keys are stored as UTF-8 bytes of the passphrase; a non-ASCII
      // passphrase guards the decode round-trip too.
      ..vaultKey = Uint8List.fromList(utf8.encode('pässwörd'));
    final biometric = _FakeBiometricService()
      ..available = true
      ..authenticateResult = true;
    final vault = _FakeVaultNotifier(); // unlock always fails (stale key)

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    // The stored bytes decode back to the exact passphrase they encoded.
    expect(vault.unlockCalls, ['pässwörd']);
    expect(find.text('Confirm using your device screen lock'), findsOneWidget);
    expect(find.textContaining('no longer matches this vault'), findsOneWidget);
    expect(find.text('Use master password'), findsOneWidget);
  });

  testWidgets('successful scan with no stored vault key shows an error',
      (tester) async {
    final keystore = _FakeKeystoreService()..biometricEnabled = true;
    final biometric = _FakeBiometricService()
      ..available = true
      ..authenticateResult = true;
    final vault = _FakeVaultNotifier();

    await _pumpLockScreen(
        tester, keystore: keystore, biometric: biometric, vault: vault);

    expect(vault.unlockCalls, isEmpty);
    expect(find.textContaining('Biometric unlock is unavailable'),
        findsOneWidget);
  });
}
