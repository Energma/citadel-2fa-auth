import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-secure key storage using Android Keystore / iOS Keychain.
class KeystoreService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _vaultKeyKey = 'citadel_vault_key';
  static const _saltKey = 'citadel_vault_salt';
  static const _biometricEnabledKey = 'citadel_biometric_enabled';
  static const _autoLockMinutesKey = 'citadel_auto_lock_minutes';
  static const _themeModeKey = 'citadel_theme_mode';
  static const _customElementColorKey = 'citadel_accent_color';
  static const _customBackgroundColorKey = 'citadel_custom_bg_color';
  static const _customTextColorKey = 'citadel_custom_text_color';
  static const _allViewGeneralSortOrderKey = 'citadel_all_view_general_sort_order';
  static const _pinHashKey = 'citadel_pin_hash'; // legacy, cleared on disable
  static const _pinEnabledKey = 'citadel_pin_enabled';
  static const _pinAttemptsKey = 'citadel_pin_attempts';
  static const _pinLockoutUntilKey = 'citadel_pin_lockout_until';
  static const _masterPasswordKey = 'citadel_master_password';
  static const _unlockMethodKey = 'citadel_unlock_method';

  /// Store the derived vault key in secure storage.
  Future<void> storeVaultKey(Uint8List key) async {
    await _storage.write(key: _vaultKeyKey, value: base64.encode(key));
  }

  /// Retrieve the stored vault key.
  Future<Uint8List?> getVaultKey() async {
    final encoded = await _storage.read(key: _vaultKeyKey);
    if (encoded == null) return null;
    return Uint8List.fromList(base64.decode(encoded));
  }

  /// Remove the stored vault key (lock).
  Future<void> clearVaultKey() async {
    await _storage.delete(key: _vaultKeyKey);
  }

  /// Store the salt used for key derivation.
  Future<void> storeSalt(Uint8List salt) async {
    await _storage.write(key: _saltKey, value: base64.encode(salt));
  }

  /// Retrieve the stored salt.
  Future<Uint8List?> getSalt() async {
    final encoded = await _storage.read(key: _saltKey);
    if (encoded == null) return null;
    return Uint8List.fromList(base64.decode(encoded));
  }

  /// Check if biometric unlock is enabled.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Enable or disable biometric unlock.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// The distinct unlock method the vault was set up with: 'pin',
  /// 'deviceCredential', 'biometric', or 'password'. 'biometric' means true
  /// fingerprint/face unlock layered on top of an app PIN; 'deviceCredential'
  /// means the phone's own screen lock (PIN/pattern/biometric via the OS) is
  /// the only unlock method, with no separate app PIN.
  ///
  /// Installs from before this field existed only recorded a single
  /// `biometricEnabled` flag for both of the above cases — this infers the
  /// right method from that older data so existing unlock setups keep
  /// working unchanged.
  Future<String> getUnlockMethod() async {
    final stored = await _storage.read(key: _unlockMethodKey);
    if (stored != null) return stored;

    final pinEnabled = await isPinEnabled();
    final biometricEnabled = await isBiometricEnabled();
    if (pinEnabled && biometricEnabled) return 'biometric';
    if (pinEnabled) return 'pin';
    if (biometricEnabled) return 'deviceCredential';
    return 'password';
  }

  Future<void> setUnlockMethod(String method) async {
    await _storage.write(key: _unlockMethodKey, value: method);
  }

  /// Check if PIN is enabled.
  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: _pinEnabledKey);
    return value == 'true';
  }

  /// Mark PIN unlock as enabled. The PIN itself is never stored — it is part of
  /// the vault passphrase, so successfully decrypting the database IS the check.
  /// This avoids keeping any PIN-derived secret (a brute-forceable target for a
  /// 6-digit PIN) in storage.
  Future<void> setPinEnabled(bool enabled) async {
    await _storage.write(key: _pinEnabledKey, value: enabled.toString());
    // Clear any legacy hash from older builds.
    await _storage.delete(key: _pinHashKey);
    // A freshly (re)configured PIN starts with a clean attempt history.
    if (enabled) await resetPinLockout();
  }

  /// Clear PIN (disable) and any legacy stored hash.
  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
    await resetPinLockout();
  }

  // --- Brute-force lockout (persisted so it survives app restarts) ---

  /// Number of consecutive wrong PIN attempts.
  Future<int> getPinAttempts() async {
    return int.tryParse(await _storage.read(key: _pinAttemptsKey) ?? '') ?? 0;
  }

  Future<void> setPinAttempts(int attempts) async {
    await _storage.write(key: _pinAttemptsKey, value: attempts.toString());
  }

  /// Time until which PIN entry is locked out, or null if not locked.
  Future<DateTime?> getPinLockoutUntil() async {
    final ms = int.tryParse(await _storage.read(key: _pinLockoutUntilKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setPinLockoutUntil(DateTime? until) async {
    if (until == null) {
      await _storage.delete(key: _pinLockoutUntilKey);
    } else {
      await _storage.write(
        key: _pinLockoutUntilKey,
        value: until.millisecondsSinceEpoch.toString(),
      );
    }
  }

  /// Reset the attempt counter and clear any active lockout.
  Future<void> resetPinLockout() async {
    await _storage.delete(key: _pinAttemptsKey);
    await _storage.delete(key: _pinLockoutUntilKey);
  }

  /// Store auto-lock timeout in minutes.
  Future<void> storeAutoLockMinutes(int minutes) async {
    await _storage.write(key: _autoLockMinutesKey, value: minutes.toString());
  }

  /// Get stored auto-lock timeout in minutes (default: 5).
  Future<int> getAutoLockMinutes() async {
    final value = await _storage.read(key: _autoLockMinutesKey);
    return int.tryParse(value ?? '') ?? 5;
  }

  /// Store theme mode preference.
  Future<void> storeThemeMode(String mode) async {
    await _storage.write(key: _themeModeKey, value: mode);
  }

  /// Get stored theme mode (default: 'system').
  Future<String> getThemeMode() async {
    return await _storage.read(key: _themeModeKey) ?? 'system';
  }

  /// Store the Custom theme's element (button/icon/highlight) color as a
  /// packed ARGB int.
  Future<void> storeCustomElementColor(int argb) async {
    await _storage.write(key: _customElementColorKey, value: argb.toString());
  }

  /// Get the stored element color, or null when the user hasn't chosen one.
  Future<int?> getCustomElementColor() async {
    final value = await _storage.read(key: _customElementColorKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Drop the custom element color and fall back to the default.
  Future<void> clearCustomElementColor() async {
    await _storage.delete(key: _customElementColorKey);
  }

  /// Store the Custom theme's background color as a packed ARGB int.
  Future<void> storeCustomBackgroundColor(int argb) async {
    await _storage.write(key: _customBackgroundColorKey, value: argb.toString());
  }

  /// Get the stored background color, or null when the user hasn't chosen one.
  Future<int?> getCustomBackgroundColor() async {
    final value = await _storage.read(key: _customBackgroundColorKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Drop the custom background color and fall back to the default.
  Future<void> clearCustomBackgroundColor() async {
    await _storage.delete(key: _customBackgroundColorKey);
  }

  /// Store the Custom theme's text color as a packed ARGB int.
  Future<void> storeCustomTextColor(int argb) async {
    await _storage.write(key: _customTextColorKey, value: argb.toString());
  }

  /// Get the stored text color, or null when the user hasn't chosen one.
  Future<int?> getCustomTextColor() async {
    final value = await _storage.read(key: _customTextColorKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Drop the custom text color and fall back to the default.
  Future<void> clearCustomTextColor() async {
    await _storage.delete(key: _customTextColorKey);
  }

  /// Store General's Home-screen position for the "All" tab, where it pools
  /// ungrouped tokens across every profile and so isn't scoped to one
  /// profile row.
  Future<void> storeAllViewGeneralSortOrder(int order) async {
    await _storage.write(
        key: _allViewGeneralSortOrderKey, value: order.toString());
  }

  /// Get the stored All-tab General position (default -1 = sorts first).
  Future<int> getAllViewGeneralSortOrder() async {
    final value = await _storage.read(key: _allViewGeneralSortOrderKey);
    return int.tryParse(value ?? '') ?? -1;
  }

  /// Store the master password for PIN-only login.
  Future<void> storeMasterPassword(String password) async {
    await _storage.write(key: _masterPasswordKey, value: password);
  }

  /// Retrieve the stored master password for PIN-only login.
  Future<String?> getMasterPassword() async {
    return await _storage.read(key: _masterPasswordKey);
  }

  /// Clear the stored master password.
  Future<void> clearMasterPassword() async {
    await _storage.delete(key: _masterPasswordKey);
  }

  /// Verify a candidate against the stored master password.
  /// Returns false if no master password is stored.
  Future<bool> verifyMasterPassword(String candidate) async {
    final stored = await _storage.read(key: _masterPasswordKey);
    if (stored == null) return false;
    // Compare fixed-length digests so the comparison is constant-time.
    final a = sha256.convert(utf8.encode(stored)).bytes;
    final b = sha256.convert(utf8.encode(candidate)).bytes;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Clear all stored keys (full reset).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
