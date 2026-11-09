import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/token_repository.dart';
import 'package:citadel_auth/ui/screens/profile_screen.dart';

/// Keeps tokens in memory and applies moves to them, so the screen re-reads
/// the result exactly as it would from the vault.
class _MemoryTokenRepository extends TokenRepository {
  _MemoryTokenRepository(this.tokens) : super(VaultDatabase());

  List<Token> tokens;

  @override
  Future<void> updateGroup(String tokenId, String? groupId) async {
    tokens = [
      for (final t in tokens)
        t.id == tokenId
            ? Token(
                id: t.id,
                issuer: t.issuer,
                account: t.account,
                secret: t.secret,
                profileId: t.profileId,
                groupId: groupId,
                sortOrder: t.sortOrder,
              )
            : t,
    ];
  }

  @override
  Future<void> updateSortOrders(Map<String, int> idToOrder) async {
    tokens = [
      for (final t in tokens) t.copyWith(sortOrder: idToOrder[t.id]),
    ];
  }
}

final _work = Profile(id: 'p1', name: 'Work', colorValue: 0xFF6366F1);
final _banks = TokenGroup(id: 'g1', profileId: 'p1', name: 'Banks');
final _dev = TokenGroup(id: 'g2', profileId: 'p1', name: 'Dev', sortOrder: 1);

Token _token(String id, String issuer, {String? groupId, int order = 0}) =>
    Token(
      id: id,
      issuer: issuer,
      account: '$id@x.y',
      secret: 'JBSWY3DPEHPK3PXP',
      profileId: 'p1',
      groupId: groupId,
      sortOrder: order,
    );

Future<_MemoryTokenRepository> _pump(WidgetTester tester) async {
  final repo = _MemoryTokenRepository([
    _token('a', 'Alpha', groupId: 'g1', order: 0),
    _token('b', 'Beta', groupId: 'g1', order: 1),
    _token('c', 'Gamma'),
  ]);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tokenRepositoryProvider.overrideWithValue(repo),
      profileListProvider.overrideWith((ref) async => [_work]),
      groupsByProfileProvider.overrideWith((ref, _) async => [_banks, _dev]),
      tokensByProfileProvider.overrideWith((ref, _) async => repo.tokens),
      tokenListProvider.overrideWith((ref) async => repo.tokens),
    ],
    child: const MaterialApp(home: ProfileScreen(initialProfileId: 'p1')),
  ));
  await tester.pumpAndSettle();
  return repo;
}

String? _groupOf(_MemoryTokenRepository repo, String id) =>
    repo.tokens.firstWhere((t) => t.id == id).groupId;

void main() {
  testWidgets('opens on the profile\'s groups, with General after them',
      (tester) async {
    await _pump(tester);
    expect(find.text('2 tokens'), findsOneWidget); // Banks
    expect(find.text('0 tokens'), findsOneWidget); // Dev
    expect(find.text('1 token'), findsOneWidget); // General
    expect(tester.getTopLeft(find.text('Dev')).dy,
        lessThan(tester.getTopLeft(find.text('General')).dy));
  });

  testWidgets('dropping a token on a group moves it there', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();

    final drag = await tester.startGesture(tester.getCenter(find.text('Gamma')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await drag.moveTo(tester.getCenter(find.text('Dev')));
    await tester.pump();
    expect(find.text('Drop to move here'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();

    expect(_groupOf(repo, 'c'), 'g2');
    expect(find.text('1 token'), findsOneWidget); // Dev now
  });

  testWidgets('dropping a token on another puts it right before that one',
      (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Banks'));
    await tester.pumpAndSettle();

    final drag = await tester.startGesture(tester.getCenter(find.text('Beta')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await drag.moveTo(tester.getCenter(find.text('Alpha')));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    final banks = repo.tokens.where((t) => t.groupId == 'g1').toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect(banks.map((t) => t.issuer), ['Beta', 'Alpha']);
  });

  testWidgets('the move button files a token without dragging',
      (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Banks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Move Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();

    expect(_groupOf(repo, 'a'), isNull);
  });
}
