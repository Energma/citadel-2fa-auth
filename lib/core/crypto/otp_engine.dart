import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';
import '../models/token.dart';

/// RFC 6238 TOTP and RFC 4226 HOTP implementation.
class OtpEngine {
  /// Generate a TOTP code for the given token at the current time.
  static String generateTotp(Token token, {DateTime? time}) {
    final now = time ?? DateTime.now();
    final timeStep = now.millisecondsSinceEpoch ~/ 1000 ~/ token.period;
    return _generateCode(token.secret, timeStep, token.digits, token.algorithm);
  }

  /// Generate the next TOTP code (for preview).
  static String generateNextTotp(Token token, {DateTime? time}) {
    final now = time ?? DateTime.now();
    final timeStep = (now.millisecondsSinceEpoch ~/ 1000 ~/ token.period) + 1;
    return _generateCode(token.secret, timeStep, token.digits, token.algorithm);
  }

  /// Generate an HOTP code for the given token at its current counter.
  static String generateHotp(Token token) {
    return _generateCode(token.secret, token.counter, token.digits, token.algorithm);
  }

  /// Generate code for any token based on its type.
  static String generateCode(Token token, {DateTime? time}) {
    return token.type == OtpType.totp
        ? generateTotp(token, time: time)
        : generateHotp(token);
  }

  /// Seconds remaining until the current TOTP code expires.
  static int remainingSeconds(Token token, {DateTime? time}) {
    final now = time ?? DateTime.now();
    final elapsed = (now.millisecondsSinceEpoch ~/ 1000) % token.period;
    return token.period - elapsed;
  }

  /// Progress fraction (0.0 to 1.0) of the current TOTP period.
  static double progress(Token token, {DateTime? time}) {
    final now = time ?? DateTime.now();
    final elapsed = (now.millisecondsSinceEpoch ~/ 1000) % token.period;
    return elapsed / token.period;
  }

  // --- Internal RFC 4226 implementation ---

  static String _generateCode(String secret, int counter, int digits, Algorithm algorithm) {
    final key = _decodeSecret(secret);
    final msg = _int64ToBytes(counter);
    final hash = _hmac(key, msg, algorithm);
    final code = _truncate(hash) % _pow10(digits);
    return code.toString().padLeft(digits, '0');
  }

  static Uint8List _decodeSecret(String secret) {
    // Normalize: uppercase, remove spaces/dashes, pad to multiple of 8
    var normalized = secret.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    while (normalized.length % 8 != 0) {
      normalized += '=';
    }
    return Uint8List.fromList(base32.decode(normalized));
  }

  static Uint8List _int64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (var i = 7; i >= 0; i--) {
      bytes[i] = value & 0xff;
      value >>= 8;
    }
    return bytes;
  }

  static Uint8List _hmac(Uint8List key, Uint8List data, Algorithm algorithm) {
    final Hash hashFn;
    switch (algorithm) {
      case Algorithm.sha256:
        hashFn = sha256;
      case Algorithm.sha512:
        hashFn = sha512;
      case Algorithm.sha1:
        hashFn = sha1;
    }
    final hmac = Hmac(hashFn, key);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  static int _truncate(Uint8List hash) {
    final offset = hash[hash.length - 1] & 0x0f;
    return ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
  }

  static int _pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  /// Validate that a Base32 secret is well-formed.
  static bool isValidSecret(String secret) {
    try {
      final decoded = _decodeSecret(secret);
      return decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
