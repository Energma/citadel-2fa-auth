import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/models/profile.dart';

void main() {
  group('Token serialization', () {
    test('toMap → fromMap preserves all fields (HOTP, tags, refs)', () {
      final created = DateTime.parse('2026-01-02T03:04:05.000');
      final updated = DateTime.parse('2026-02-03T04:05:06.000');
      final token = Token(
        id: 'tok-1',
        issuer: 'AWS',
        account: 'root@example.com',
        secret: 'GEZDGNBVGY3TQOJQ',
        type: OtpType.hotp,
        algorithm: Algorithm.sha512,
        digits: 8,
        period: 60,
        counter: 7,
        iconPath: 'icons/aws.png',
        profileId: 'prof-9',
        groupId: 'grp-3',
        tags: const ['work', 'cloud'],
        isPinned: true,
        sortOrder: 5,
        createdAt: created,
        updatedAt: updated,
      );

      final restored = Token.fromMap(token.toMap());

      expect(restored.id, 'tok-1');
      expect(restored.issuer, 'AWS');
      expect(restored.account, 'root@example.com');
      expect(restored.secret, 'GEZDGNBVGY3TQOJQ');
      expect(restored.type, OtpType.hotp);
      expect(restored.algorithm, Algorithm.sha512);
      expect(restored.digits, 8);
      expect(restored.period, 60);
      expect(restored.counter, 7);
      expect(restored.iconPath, 'icons/aws.png');
      expect(restored.profileId, 'prof-9');
      expect(restored.groupId, 'grp-3');
      expect(restored.tags, ['work', 'cloud']);
      expect(restored.isPinned, true);
      expect(restored.sortOrder, 5);
      expect(restored.createdAt, created);
      expect(restored.updatedAt, updated);
    });

    test('empty tag list round-trips to an empty list (not [""])', () {
      final token = Token(issuer: 'X', account: 'a', secret: 'S', tags: const []);
      final restored = Token.fromMap(token.toMap());
      expect(restored.tags, isEmpty);
    });

    test('defaults are applied for a minimal token', () {
      final token = Token(issuer: 'GitHub', account: 'octocat', secret: 'JBSWY3DPEHPK3PXP');
      final restored = Token.fromMap(token.toMap());
      expect(restored.type, OtpType.totp);
      expect(restored.algorithm, Algorithm.sha1);
      expect(restored.digits, 6);
      expect(restored.period, 30);
      expect(restored.counter, 0);
      expect(restored.isPinned, false);
      expect(restored.profileId, isNull);
      expect(restored.groupId, isNull);
    });
  });

  group('Token otpauth URI', () {
    test('toUri → fromUri round-trips a TOTP token', () {
      final token = Token(
        issuer: 'GitHub',
        account: 'octocat',
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: Algorithm.sha256,
        digits: 6,
        period: 30,
      );
      final restored = Token.fromUri(token.toUri());
      expect(restored.issuer, 'GitHub');
      expect(restored.account, 'octocat');
      expect(restored.secret, 'JBSWY3DPEHPK3PXP');
      expect(restored.algorithm, Algorithm.sha256);
      expect(restored.type, OtpType.totp);
    });

    test('toUri → fromUri round-trips an HOTP token with counter', () {
      final token = Token(
        issuer: 'Bank',
        account: 'me',
        secret: 'GEZDGNBVGY3TQOJQ',
        type: OtpType.hotp,
        counter: 42,
      );
      final restored = Token.fromUri(token.toUri());
      expect(restored.type, OtpType.hotp);
      expect(restored.counter, 42);
    });

    test('fromUri rejects a non-otpauth scheme', () {
      expect(() => Token.fromUri('https://example.com'), throwsFormatException);
    });

    test('fromUri rejects a URI with no secret', () {
      expect(
        () => Token.fromUri('otpauth://totp/GitHub:octocat?issuer=GitHub'),
        throwsFormatException,
      );
    });

    test('fromUri uppercases the secret', () {
      final t = Token.fromUri('otpauth://totp/X:a?secret=jbswy3dpehpk3pxp');
      expect(t.secret, 'JBSWY3DPEHPK3PXP');
    });
  });

  group('Profile serialization', () {
    test('toMap → fromMap preserves all fields', () {
      final created = DateTime.parse('2026-03-04T05:06:07.000');
      final profile = Profile(
        id: 'prof-1',
        name: 'Personal',
        colorValue: 0xFF2196F3,
        iconName: 'home',
        sortOrder: 2,
        generalSortOrder: 1,
        createdAt: created,
      );
      final restored = Profile.fromMap(profile.toMap());
      expect(restored.id, 'prof-1');
      expect(restored.name, 'Personal');
      expect(restored.colorValue, 0xFF2196F3);
      expect(restored.color, const Color(0xFF2196F3));
      expect(restored.iconName, 'home');
      expect(restored.sortOrder, 2);
      expect(restored.generalSortOrder, 1);
      expect(restored.createdAt, created);
    });

    test('defaults generalSortOrder to -1 when omitted', () {
      final profile = Profile(name: 'Work', colorValue: 0xFF06B6D4);
      final restored = Profile.fromMap(profile.toMap());
      expect(restored.generalSortOrder, -1);
    });
  });

  group('TokenGroup serialization', () {
    test('toMap → fromMap preserves all fields', () {
      final group = TokenGroup(
        id: 'grp-1',
        profileId: 'prof-1',
        name: 'Email',
        sortOrder: 3,
      );
      final restored = TokenGroup.fromMap(group.toMap());
      expect(restored.id, 'grp-1');
      expect(restored.profileId, 'prof-1');
      expect(restored.name, 'Email');
      expect(restored.sortOrder, 3);
    });
  });
}
