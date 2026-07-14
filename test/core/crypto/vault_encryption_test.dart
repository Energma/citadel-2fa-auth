import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/crypto/vault_encryption.dart';

void main() {
  group('VaultEncryption', () {
    test('generateSalt produces 32 random bytes that differ each call', () {
      final a = VaultEncryption.generateSalt();
      final b = VaultEncryption.generateSalt();
      expect(a.length, 32);
      expect(b.length, 32);
      expect(a, isNot(equals(b)));
    });

    test('encrypt/decrypt round-trips arbitrary bytes', () async {
      final salt = VaultEncryption.generateSalt();
      final key = await VaultEncryption.deriveKey('correct horse battery', salt);
      final plaintext = Uint8List.fromList(List.generate(200, (i) => i % 256));

      final ciphertext = await VaultEncryption.encrypt(plaintext, key);
      final restored = await VaultEncryption.decrypt(ciphertext, key);

      expect(restored, equals(plaintext));
    });

    test('encryptString/decryptString round-trips unicode text', () async {
      final salt = VaultEncryption.generateSalt();
      final key = await VaultEncryption.deriveKey('p@ssw0rd', salt);
      const secret = 'JBSWY3DPEHPK3PXP — 🔐 café';

      final ciphertext = await VaultEncryption.encryptString(secret, key);
      final restored = await VaultEncryption.decryptString(ciphertext, key);

      expect(restored, secret);
    });

    test('ciphertext is non-deterministic (random nonce per encryption)', () async {
      final salt = VaultEncryption.generateSalt();
      final key = await VaultEncryption.deriveKey('pw', salt);
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final c1 = await VaultEncryption.encrypt(data, key);
      final c2 = await VaultEncryption.encrypt(data, key);

      expect(c1, isNot(equals(c2)));
    });

    test('decryption with the wrong key fails (GCM auth tag rejects it)', () async {
      final salt = VaultEncryption.generateSalt();
      final rightKey = await VaultEncryption.deriveKey('right', salt);
      final wrongKey = await VaultEncryption.deriveKey('wrong', salt);
      final ciphertext =
          await VaultEncryption.encryptString('top secret', rightKey);

      expect(
        () => VaultEncryption.decryptString(ciphertext, wrongKey),
        throwsA(anything),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final salt = VaultEncryption.generateSalt();
      final key = await VaultEncryption.deriveKey('pw', salt);
      final ciphertext = await VaultEncryption.encrypt(
        Uint8List.fromList([10, 20, 30]),
        key,
      );
      // Flip a bit in the ciphertext body.
      ciphertext[ciphertext.length - 1] ^= 0xFF;

      expect(
        () => VaultEncryption.decrypt(ciphertext, key),
        throwsA(anything),
      );
    });

    test('same password + same salt derives the same key', () async {
      final salt = VaultEncryption.generateSalt();
      final k1 = await VaultEncryption.deriveKey('repeatable', salt);
      final k2 = await VaultEncryption.deriveKey('repeatable', salt);

      final data = Uint8List.fromList([42]);
      final ciphertext = await VaultEncryption.encrypt(data, k1);
      // k2 must decrypt what k1 encrypted.
      expect(await VaultEncryption.decrypt(ciphertext, k2), equals(data));
    });
  });
}
