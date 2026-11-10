import 'dart:convert';
import 'dart:io';

import 'package:citadel_auth/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readConfig(String name) =>
    jsonDecode(File('config/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('build config profiles', () {
    test('prod keeps screenshot and recording restrictions on', () {
      expect(_readConfig('prod')['DEMO_MODE'], isFalse);
      expect(_readConfig('prod').containsKey('ALLOW_SCREENSHOTS'), isFalse);
    });

    test('demo (used by iOS test builds) lifts the restrictions', () {
      expect(_readConfig('demo')['DEMO_MODE'], isTrue);
    });

    test('a build with no flags is locked down like prod', () {
      // Tests run without --dart-define, so this is the no-flags default.
      expect(AppConfig.demoMode, isFalse);
      expect(AppConfig.allowScreenshots, isFalse);
    });
  });

  group('dev.sh', () {
    final script = File('dev.sh').readAsStringSync();

    String fn(String name) => RegExp('^$name\\(\\) \\{.*\\}\$', multiLine: true)
        .firstMatch(script)!
        .group(0)!;

    test('production ipa export stays on prod.json', () {
      expect(fn('ipa_build'), contains('config/prod.json'));
      expect(fn('ipa_build'), isNot(contains('demo.json')));
    });

    test('iOS testing builds use demo.json', () {
      for (final name in ['ios_build', 'ios_device_build', 'ipa_test_build']) {
        expect(fn(name), contains('--dart-define-from-file=config/demo.json'),
            reason: name);
      }
    });
  });
}
