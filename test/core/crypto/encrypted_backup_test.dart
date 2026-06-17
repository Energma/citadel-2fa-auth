import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/crypto/import_export.dart';
import 'package:citadel_auth/core/crypto/vault_encryption.dart';
import 'package:citadel_auth/core/models/token.dart';

/// Builds an encrypted backup string in the exact on-disk format used by the
/// Settings "Encrypted Export" feature: `base64(salt)\n<ciphertext>`.
Future<String> _buildEncryptedBackup(
  List<Token> tokens,
  String password,
) async {
  final jsonStr = ImportExport.exportToJson(tokens);
  final salt = VaultEncryption.generateSalt();
  final key = await VaultEncryption.deriveKey(password, salt);
  final ciphertext = await VaultEncryption.encryptString(jsonStr, key);
  return '${base64.encode(salt)}\n$ciphertext';
}

/// Mirrors SettingsScreen._decryptExport — the import-side counterpart that
/// recovers the token JSON from an encrypted backup string.
Future<String> _decryptBackup(String content, String password) async {
  final newlineIdx = content.indexOf('\n');
  if (newlineIdx <= 0) {
    throw const FormatException('Malformed encrypted backup');
  }
  final salt = base64.decode(content.substring(0, newlineIdx).trim());
  final ciphertext = content.substring(newlineIdx + 1).trim();
  final key = await VaultEncryption.deriveKey(password, salt);
  return VaultEncryption.decryptString(ciphertext, key);
}

void main() {
  final tokens = [
    Token(
      issuer: 'GitHub',
      account: 'octocat',
      secret: 'JBSWY3DPEHPK3PXP',
      tags: const ['work'],
    ),
    Token(
      issuer: 'AWS',
      account: 'root',
      secret: 'GEZDGNBVGY3TQOJQ',
      type: OtpType.hotp,
      algorithm: Algorithm.sha256,
      digits: 8,
      counter: 5,
    ),
  ];

  group('Encrypted backup round-trip', () {
    test('export → encrypt → decrypt → import recovers all tokens', () async {
      const password = 'correct horse battery staple';
      final backup = await _buildEncryptedBackup(tokens, password);

      final restoredJson = await _decryptBackup(backup, password);
      final restored = ImportExport.importFromJson(restoredJson);

      expect(restored.length, tokens.length);
      expect(restored[0].issuer, 'GitHub');
      expect(restored[0].secret, 'JBSWY3DPEHPK3PXP');
      expect(restored[0].tags, ['work']);
      expect(restored[1].type, OtpType.hotp);
      expect(restored[1].algorithm, Algorithm.sha256);
      expect(restored[1].digits, 8);
      expect(restored[1].counter, 5);
    });

    test('wrong password fails to decrypt the backup', () async {
      final backup = await _buildEncryptedBackup(tokens, 'right-password');

      expect(
        () => _decryptBackup(backup, 'wrong-password'),
        throwsA(anything),
      );
    });

    test('backup file format is base64(salt) on its own first line', () async {
      final backup = await _buildEncryptedBackup(tokens, 'pw');
      final firstLine = backup.substring(0, backup.indexOf('\n'));

      // The salt line must decode to exactly 32 bytes — the contract the
      // import-side encrypted-file detection relies on.
      expect(base64.decode(firstLine).length, 32);
    });
  });
}
