import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/ui/widgets/token_card.dart';

final _token =
    Token(issuer: 'GitHub', account: 'a@b.c', secret: 'JBSWY3DPEHPK3PXP');

Future<void> _pump(WidgetTester tester, {VoidCallback? onEdit}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TokenCard(token: _token, onEdit: onEdit)),
    ));

void main() {
  testWidgets('the pencil opens the editor', (tester) async {
    var edits = 0;
    await _pump(tester, onEdit: () => edits++);

    await tester.tap(find.byTooltip('Edit token'));
    expect(edits, 1);

    // Stop the card's code timer before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no pencil when the card cannot be edited', (tester) async {
    await _pump(tester);
    expect(find.byTooltip('Edit token'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
