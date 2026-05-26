import 'dart:convert';
import 'dart:typed_data';
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
  static const _pinHashKey = 'citadel_pin_hash';
  static const _pinEnabledKey = 'citadel_pin_enabled';
  static const _masterPasswordKey = 'citadel_master_password';

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

  /// Check if PIN is enabled.
  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: _pinEnabledKey);
    return value == 'true';
  }

  /// Store the SHA-256 hash of the PIN for quick validation.
  Future<void> storePinHash(String hash) async {
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: 'true');
  }

  /// Get the stored PIN hash.
  Future<String?> getPinHash() async {
    return _storage.read(key: _pinHashKey);
  }

  /// Clear PIN (disable).
  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
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

  /// Clear all stored keys (full reset).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
