import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS project targets iPhone and iPad (EI-60)', () {
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
        .allMatches(project)
        .map((m) => m.group(1))
        .toSet();
    expect(families, {'"1,2"'});
    expect(File('ios/Runner/Info.plist').readAsStringSync(),
        contains('UISupportedInterfaceOrientations~ipad'));
  });
}
