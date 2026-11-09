import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/token_repository.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/home_screen.dart';
import 'package:citadel_auth/ui/theme/app_theme.dart';

/// Applies moves to in-memory tokens, the way the vault would.
class _MemoryTokenRepository extends TokenRepository {
  _MemoryTokenRepository(this.tokens) : super(VaultDatabase());

  List<Token> tokens;

  Token _with(Token t, {required String? profileId, required String? groupId}) =>
      Token(
        id: t.id,
        issuer: t.issuer,
        account: t.account,
        secret: t.secret,
        profileId: profileId,
        groupId: groupId,
      );

  @override
  Future<void> updateProfile(String tokenId, String? profileId) async =>
      tokens = [
        for (final t in tokens)
          t.id == tokenId
              ? _with(t, profileId: profileId, groupId: t.groupId)
              : t,
      ];

  @override
  Future<void> updateSortOrders(Map<String, int> idToOrder) async {}

  @override
  Future<void> updateGroup(String tokenId, String? groupId) async => tokens = [
        for (final t in tokens)
          t.id == tokenId
              ? _with(t, profileId: t.profileId, groupId: groupId)
              : t,
      ];
}

class _QuietKeystore extends KeystoreService {
  @override
  Future<void> storeExpandedSections(Set<String> ids) async {}
}

final _personal =
    Profile(id: 'p1', name: 'Personal', colorValue: 0xFF6366F1, sortOrder: 0);
final _work =
    Profile(id: 'p2', name: 'Work', colorValue: 0xFF06B6D4, sortOrder: 1);
final _dev = TokenGroup(id: 'g2', profileId: 'p2', name: 'Dev');

Future<_MemoryTokenRepository> _pumpAll(WidgetTester tester) async {
  // A token with no profile: it lives in the All tab's own General.
  final repo = _MemoryTokenRepository([
    Token(id: 'a', issuer: 'Alpha', account: 'a@b.c', secret: 'JBSWY3DPEHPK3PXP'),
  ]);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      keystoreServiceProvider.overrideWithValue(_QuietKeystore()),
      expandedSectionsProvider.overrideWith((ref) => {'__general__:none'}),
      tokenRepositoryProvider.overrideWithValue(repo),
      tokenListProvider.overrideWith((ref) async => repo.tokens),
      profileListProvider.overrideWith((ref) async => [_personal, _work]),
      groupListProvider.overrideWith((ref) async => [_dev]),
      allGroupsProvider.overrideWith((ref) async => [_dev]),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme(), home: const HomeScreen()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('a token dropped on another profile\'s category moves there',
      (tester) async {
    final repo = await _pumpAll(tester);

    final drag = await tester.startGesture(tester.getCenter(find.text('Alpha')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await drag.moveTo(tester.getCenter(find.text('Dev')));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    // Profile and category move together, or Dev would never show it.
    expect(repo.tokens.single.profileId, 'p2');
    expect(repo.tokens.single.groupId, 'g2');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('press and release opens the sheet, one tap files it',
      (tester) async {
    final repo = await _pumpAll(tester);

    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Move Alpha to'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Dev')));
    await tester.pumpAndSettle();

    expect(repo.tokens.single.profileId, 'p2');
    expect(repo.tokens.single.groupId, 'g2');

    await tester.pumpWidget(const SizedBox());
  });
}
