import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/crypto/otp_engine.dart';
import 'package:citadel_auth/core/models/token.dart';

void main() {
  group('OtpEngine - RFC 6238 Test Vectors', () {
    // RFC 6238 test secret (ASCII "12345678901234567890" = Base32 "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
    const sha1Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    // SHA256 secret: "12345678901234567890123456789012" = 32 bytes
    const sha256Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
    // SHA512 secret: "1234567890123456789012345678901234567890123456789012345678901234" = 64 bytes
    const sha512Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

    // Test time: 59 seconds since epoch (time step 1)
    final time59 = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
    // Test time: 1111111109 seconds since epoch
    final time1111111109 = DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true);
    // Test time: 20000000000 seconds since epoch
    final time20000000000 = DateTime.fromMillisecondsSinceEpoch(20000000000 * 1000, isUtc: true);

    test('SHA1 at time=59 produces 94287082', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha1Secret,
        algorithm: Algorithm.sha1,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time59), '94287082');
    });

    test('SHA256 at time=59 produces 46119246', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha256Secret,
        algorithm: Algorithm.sha256,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time59), '46119246');
    });

    test('SHA512 at time=59 produces 90693936', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha512Secret,
        algorithm: Algorithm.sha512,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time59), '90693936');
    });

    test('SHA1 at time=1111111109 produces 07081804', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha1Secret,
        algorithm: Algorithm.sha1,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time1111111109), '07081804');
    });

    test('SHA256 at time=1111111109 produces 68084774', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha256Secret,
        algorithm: Algorithm.sha256,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time1111111109), '68084774');
    });

    test('SHA512 at time=1111111109 produces 25091201', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha512Secret,
        algorithm: Algorithm.sha512,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time1111111109), '25091201');
    });

    test('SHA1 at time=20000000000 produces 65353130', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: sha1Secret,
        algorithm: Algorithm.sha1,
        digits: 8,
        period: 30,
      );
      expect(OtpEngine.generateTotp(token, time: time20000000000), '65353130');
    });
  });

  group('OtpEngine - 6-digit TOTP', () {
    test('generates 6-digit codes by default', () {
      final token = Token(
        issuer: 'GitHub',
        account: 'user@test.com',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      final code = OtpEngine.generateTotp(token);
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
    });
  });

  group('OtpEngine - HOTP', () {
    // RFC 4226 test vector: secret = "12345678901234567890", counter = 0..9
    const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    final expected = [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ];

    for (var i = 0; i < expected.length; i++) {
      test('counter=$i produces ${expected[i]}', () {
        final token = Token(
          issuer: 'test',
          account: 'test',
          secret: secret,
          type: OtpType.hotp,
          counter: i,
        );
        expect(OtpEngine.generateHotp(token), expected[i]);
      });
    }
  });

  group('OtpEngine - HOTP with SHA256/SHA512', () {
    // Golden values cross-checked independently via Python's hmac/hashlib
    // against the same secrets used by the RFC 6238 TOTP group above (counter
    // 1 matches the TOTP time=59 vector for each algorithm, since TOTP is
    // HOTP with the time-step as the counter).
    const sha256Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
    const sha512Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

    final expectedSha256 = [
      '18920136',
      '46119246',
      '30882438',
      '02975832',
      '54791148',
      '89744399',
      '75668833',
      '11276785',
      '53778880',
      '43242340',
    ];
    final expectedSha512 = [
      '53550594',
      '90693936',
      '68765371',
      '02628588',
      '03977270',
      '59407012',
      '30383831',
      '21656234',
      '77504704',
      '56467051',
    ];

    for (var i = 0; i < expectedSha256.length; i++) {
      test('SHA256 counter=$i produces ${expectedSha256[i]}', () {
        final token = Token(
          issuer: 'test',
          account: 'test',
          secret: sha256Secret,
          type: OtpType.hotp,
          algorithm: Algorithm.sha256,
          digits: 8,
          counter: i,
        );
        expect(OtpEngine.generateHotp(token), expectedSha256[i]);
      });
    }

    for (var i = 0; i < expectedSha512.length; i++) {
      test('SHA512 counter=$i produces ${expectedSha512[i]}', () {
        final token = Token(
          issuer: 'test',
          account: 'test',
          secret: sha512Secret,
          type: OtpType.hotp,
          algorithm: Algorithm.sha512,
          digits: 8,
          counter: i,
        );
        expect(OtpEngine.generateHotp(token), expectedSha512[i]);
      });
    }
  });

  group('OtpEngine - remainingSeconds', () {
    test('returns correct remaining seconds', () {
      final token = Token(
        issuer: 'test',
        account: 'test',
        secret: 'JBSWY3DPEHPK3PXP',
        period: 30,
      );
      final time = DateTime.fromMillisecondsSinceEpoch(10 * 1000);
      expect(OtpEngine.remainingSeconds(token, time: time), 20);
    });
  });

  group('OtpEngine - isValidSecret', () {
    test('valid Base32 secret returns true', () {
      expect(OtpEngine.isValidSecret('JBSWY3DPEHPK3PXP'), true);
    });

    test('empty secret returns false', () {
      expect(OtpEngine.isValidSecret(''), false);
    });

    test('invalid characters return false', () {
      expect(OtpEngine.isValidSecret('!!!invalid!!!'), false);
    });
  });

  group('Token - URI parsing', () {
    test('parse standard otpauth URI', () {
      final token = Token.fromUri(
        'otpauth://totp/GitHub:user@email.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1&digits=6&period=30',
      );
      expect(token.issuer, 'GitHub');
      expect(token.account, 'user@email.com');
      expect(token.secret, 'JBSWY3DPEHPK3PXP');
      expect(token.type, OtpType.totp);
      expect(token.algorithm, Algorithm.sha1);
      expect(token.digits, 6);
      expect(token.period, 30);
    });

    test('parse HOTP URI', () {
      final token = Token.fromUri(
        'otpauth://hotp/Service:user?secret=JBSWY3DPEHPK3PXP&counter=42',
      );
      expect(token.type, OtpType.hotp);
      expect(token.counter, 42);
    });

    test('round-trip URI', () {
      final original = Token(
        issuer: 'Test',
        account: 'user@test.com',
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: Algorithm.sha256,
        digits: 8,
        period: 60,
      );
      final uri = original.toUri();
      final parsed = Token.fromUri(uri);
      expect(parsed.issuer, original.issuer);
      expect(parsed.account, original.account);
      expect(parsed.secret, original.secret);
      expect(parsed.algorithm, original.algorithm);
      expect(parsed.digits, original.digits);
      expect(parsed.period, original.period);
    });
  });
}
