import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/crypto/import_export.dart';
import 'package:citadel_auth/core/models/token.dart';

void main() {
  group('ImportExport - Citadel format', () {
    test('round-trip export/import preserves tokens', () {
      final tokens = [
        Token(
          issuer: 'GitHub',
          account: 'user@test.com',
          secret: 'JBSWY3DPEHPK3PXP',
          algorithm: Algorithm.sha1,
          digits: 6,
          period: 30,
        ),
        Token(
          issuer: 'AWS',
          account: 'admin',
          secret: 'GEZDGNBVGY3TQOJQ',
          algorithm: Algorithm.sha256,
          digits: 8,
          period: 60,
        ),
      ];

      final exported = ImportExport.exportToJson(tokens);
      final imported = ImportExport.importFromJson(exported);

      expect(imported.length, 2);
      expect(imported[0].issuer, 'GitHub');
      expect(imported[0].secret, 'JBSWY3DPEHPK3PXP');
      expect(imported[1].issuer, 'AWS');
      expect(imported[1].digits, 8);
    });
  });

  group('ImportExport - Aegis format', () {
    test('imports Aegis JSON export', () {
      final aegisData = json.encode({
        'version': 2,
        'db': {
          'entries': [
            {
              'type': 'totp',
              'name': 'user@gmail.com',
              'issuer': 'Google',
              'info': {
                'secret': 'JBSWY3DPEHPK3PXP',
                'algo': 'SHA1',
                'digits': 6,
                'period': 30,
              },
            },
          ],
        },
      });

      final tokens = ImportExport.importFromJson(aegisData);
      expect(tokens.length, 1);
      expect(tokens[0].issuer, 'Google');
      expect(tokens[0].account, 'user@gmail.com');
    });
  });

  group('ImportExport - 2FAS format', () {
    test('imports 2FAS JSON export', () {
      final data = json.encode({
        'services': [
          {
            'name': 'GitHub',
            'otp': {
              'account': 'octocat',
              'secret': 'JBSWY3DPEHPK3PXP',
              'tokenType': 'TOTP',
              'algorithm': 'SHA1',
              'digits': 6,
              'period': 30,
            },
          },
          {
            'name': 'Bank',
            'otp': {
              'account': 'me',
              'secret': 'GEZDGNBVGY3TQOJQ',
              'tokenType': 'HOTP',
              'counter': 9,
            },
          },
        ],
      });

      final tokens = ImportExport.importFromJson(data);
      expect(tokens.length, 2);
      expect(tokens[0].issuer, 'GitHub');
      expect(tokens[0].account, 'octocat');
      expect(tokens[1].type, OtpType.hotp);
      expect(tokens[1].counter, 9);
    });
  });

  group('ImportExport - Ente format', () {
    test('imports Ente export from rawData otpauth URIs', () {
      final data = json.encode({
        'items': [
          {
            'rawData':
                'otpauth://totp/Google:user@gmail.com?secret=GEZDGNBVGY3TQOJQ&issuer=Google',
          },
        ],
      });

      final tokens = ImportExport.importFromJson(data);
      expect(tokens.length, 1);
      expect(tokens[0].issuer, 'Google');
      expect(tokens[0].secret, 'GEZDGNBVGY3TQOJQ');
    });
  });

  group('ImportExport - Citadel tags', () {
    test('re-importing a Citadel export preserves token tags', () {
      final exported = ImportExport.exportToJson([
        Token(
          issuer: 'GitHub',
          account: 'octocat',
          secret: 'JBSWY3DPEHPK3PXP',
          tags: const ['work', 'dev'],
        ),
      ]);
      final restored = ImportExport.importFromJson(exported);
      expect(restored.single.tags, ['work', 'dev']);
    });
  });

  group('ImportExport - errors', () {
    test('unrecognized format throws FormatException', () {
      expect(
        () => ImportExport.importFromJson('{"totally":"unknown"}'),
        throwsFormatException,
      );
    });
  });

  group('ImportExport - URI list', () {
    test('imports otpauth URI list', () {
      const uris = '''
otpauth://totp/GitHub:user@test.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
otpauth://totp/Google:user@gmail.com?secret=GEZDGNBVGY3TQOJQ&issuer=Google
''';
      final tokens = ImportExport.importFromJson(uris);
      expect(tokens.length, 2);
      expect(tokens[0].issuer, 'GitHub');
      expect(tokens[1].issuer, 'Google');
    });
  });

  group('ImportExport - URI export', () {
    test('exports as otpauth URI list', () {
      final tokens = [
        Token(
          issuer: 'GitHub',
          account: 'user@test.com',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      ];

      final uris = ImportExport.exportToUriList(tokens);
      expect(uris, contains('otpauth://totp/'));
      expect(uris, contains('JBSWY3DPEHPK3PXP'));
    });
  });
}
