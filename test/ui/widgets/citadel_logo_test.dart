import 'package:citadel_auth/ui/widgets/citadel_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> assetFor(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const CitadelLogo(size: 48),
    ));
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    return (picture.bytesLoader as SvgAssetLoader).assetName;
  }

  testWidgets('light theme shows the positive mark', (tester) async {
    expect(await assetFor(tester, Brightness.light), contains('positive'));
  });

  testWidgets('dark theme shows the negative mark', (tester) async {
    expect(await assetFor(tester, Brightness.dark), contains('negative'));
  });
}
