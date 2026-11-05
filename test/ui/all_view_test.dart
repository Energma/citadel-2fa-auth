import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/all_view_layout.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/profile_repository.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/all_view_editor_screen.dart';
import 'package:citadel_auth/ui/screens/home_screen.dart';
import 'package:citadel_auth/ui/theme/app_theme.dart';

class _FakeKeystore extends KeystoreService {
  String? stored;

  @override
  Future<void> storeAllViewLayout(String json) async => stored = json;
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(VaultDatabase());

  Map<String, int>? groupOrders;

  @override
  Future<void> updateGroupSortOrders(Map<String, int> idToOrder) async =>
      groupOrders = idToOrder;

  @override
  Future<void> updateGeneralSortOrder(String profileId, int order) async {}
}

final _personal =
    Profile(id: 'p1', name: 'Personal', colorValue: 0xFF6366F1, sortOrder: 0);
final _work =
    Profile(id: 'p2', name: 'Work', colorValue: 0xFF06B6D4, sortOrder: 1);
final _banks = TokenGroup(id: 'g1', profileId: 'p1', name: 'Banks', sortOrder: 0);
final _games = TokenGroup(id: 'g3', profileId: 'p1', name: 'Games', sortOrder: 1);
final _dev = TokenGroup(id: 'g2', profileId: 'p2', name: 'Dev');

List<Override> _overrides(_FakeKeystore keystore, {String? activeProfile}) => [
      keystoreServiceProvider.overrideWithValue(keystore),
      activeProfileIdProvider.overrideWith((ref) => activeProfile),
      tokenListProvider.overrideWith((ref) async => <Token>[]),
      profileListProvider.overrideWith((ref) async => [_personal, _work]),
      groupListProvider.overrideWith((ref) async => activeProfile == null
          ? [_banks, _games, _dev]
          : [_banks, _games]),
    ];

Future<void> _pump(WidgetTester tester, Widget home, List<Override> overrides) async {
  // Wider than a phone: the test font renders every glyph 1em wide, which
  // overflows the app bar title at real phone widths.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.darkTheme(), home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('All tab shows categories from every profile, labeled by owner',
      (tester) async {
    await _pump(tester, const HomeScreen(), _overrides(_FakeKeystore()));
    expect(find.text('Banks'), findsOneWidget);
    expect(find.text('Dev'), findsOneWidget);
    // Once on the tab bar, once as the Dev section's owner label.
    expect(find.text('Work'), findsNWidgets(2));
  });

  testWidgets('All tab leaves out hidden categories and follows saved order',
      (tester) async {
    await _pump(tester, const HomeScreen(), [
      ..._overrides(_FakeKeystore()),
      allViewLayoutProvider.overrideWith((ref) =>
          const AllViewLayout(order: ['g2', 'g1'], hidden: {'g3'})),
    ]);
    expect(find.text('Games'), findsNothing);
    expect(tester.getTopLeft(find.text('Dev')).dy,
        lessThan(tester.getTopLeft(find.text('Banks')).dy));
  });

  testWidgets('hiding everything leaves a way back to the editor',
      (tester) async {
    await _pump(tester, const HomeScreen(), [
      ..._overrides(_FakeKeystore()),
      allViewLayoutProvider.overrideWith(
          (ref) => const AllViewLayout(hidden: {'g1', 'g2', 'g3'})),
    ]);
    expect(find.text('Nothing selected for All'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Customize All'));
    await tester.pumpAndSettle();
    expect(find.byType(AllViewEditorScreen), findsOneWidget);
  });

  testWidgets('editor switch hides a category and persists it', (tester) async {
    final keystore = _FakeKeystore();
    await _pump(tester, const AllViewEditorScreen(), _overrides(keystore));

    final row = find.widgetWithText(ListTile, 'Dev');
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(AllViewLayout.fromJsonString(keystore.stored).hidden, {'g2'});
  });

  testWidgets('editor profile chip hides all of that profile', (tester) async {
    final keystore = _FakeKeystore();
    await _pump(tester, const AllViewEditorScreen(), _overrides(keystore));

    await tester.tap(find.widgetWithText(FilterChip, 'Personal'));
    await tester.pumpAndSettle();

    expect(AllViewLayout.fromJsonString(keystore.stored).hidden,
        {AllViewSection.generalId('p1'), 'g1', 'g3'});
  });

  testWidgets('a profile tab reorders its categories on the groups themselves',
      (tester) async {
    final repo = _FakeProfileRepository();
    final keystore = _FakeKeystore();
    await _pump(tester, const HomeScreen(), [
      ..._overrides(keystore, activeProfile: 'p1'),
      profileRepositoryProvider.overrideWithValue(repo),
    ]);

    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final distance = tester.getTopLeft(find.text('Games')).dy -
        tester.getTopLeft(find.text('Banks')).dy;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, distance / 4));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repo.groupOrders, {'g3': 0, 'g1': 1});
    expect(keystore.stored, isNull, reason: 'must not touch the All layout');
  });
}
