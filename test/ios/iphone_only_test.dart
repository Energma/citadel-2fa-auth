import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS project targets iPhone only (EI-58)', () {
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
        .allMatches(project)
        .map((m) => m.group(1))
        .toSet();
    expect(families, {'1'});
    expect(File('ios/Runner/Info.plist').readAsStringSync(),
        isNot(contains('~ipad')));
  });
}
