import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/ui/widgets/rolling_code.dart';

Widget _app(String code) => MaterialApp(
      home: Scaffold(
        body: RollingCode(code: code, style: const TextStyle(fontSize: 20)),
      ),
    );

void main() {
  testWidgets('digits roll in order, and only the ones that changed',
      (tester) async {
    await tester.pumpWidget(_app('111222'));
    expect(find.text('1'), findsNWidgets(3));

    await tester.pumpWidget(_app('911229'));
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-roll: the first changed digit is further along than the last.
    final firstNew = tester.widgetList<Opacity>(find.ancestor(
        of: find.text('9').first, matching: find.byType(Opacity)));
    final lastNew = tester.widgetList<Opacity>(find.ancestor(
        of: find.text('9').last, matching: find.byType(Opacity)));
    expect(firstNew.single.opacity, greaterThan(lastNew.single.opacity));

    // Unchanged digits stay put instead of rolling to themselves.
    expect(find.text('1'), findsNWidgets(3));

    await tester.pumpAndSettle();
    expect(find.text('9'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2'), findsNWidgets(2));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('a code of a different length swaps without crashing',
      (tester) async {
    await tester.pumpWidget(_app('123456'));
    await tester.pumpWidget(_app('12345678'));
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('screen readers get the whole code as one label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app('123456'));
    expect(find.bySemanticsLabel('123456'), findsOneWidget);
    handle.dispose();
  });
}
