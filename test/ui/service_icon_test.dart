import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/ui/widgets/service_icon.dart';

Future<void> _pump(WidgetTester tester, String? iconPath, String issuer) =>
    tester.pumpWidget(MaterialApp(
      home: ServiceIcon(
          issuer: issuer, account: '', iconPath: iconPath, useFavicon: false),
    ));

void main() {
  testWidgets('a chosen service beats the one the name implies', (tester) async {
    await _pump(tester, ServiceIcon.iconForService('slack'), 'Unknown Bank');
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/icons/services/slack.svg');
  });

  testWidgets('a chosen emoji is shown', (tester) async {
    await _pump(tester, ServiceIcon.iconForEmoji('🏦'), 'GitHub');
    expect(find.text('🏦'), findsOneWidget);
  });

  testWidgets('unrecognized stored values fall back to the automatic icon',
      (tester) async {
    for (final bad in ['icons/aws.png', 'service:nope', 'emoji:']) {
      await _pump(tester, bad, 'Acme');
      expect(find.text('A'), findsOneWidget, reason: bad);
    }
  });

  test('every offered service has a label', () {
    expect(ServiceIcon.pickableServices, contains('microsoft'));
    expect(ServiceIcon.serviceLabel('github'), 'GitHub');
    expect(ServiceIcon.serviceLabel('slack'), 'Slack');
  });
}
