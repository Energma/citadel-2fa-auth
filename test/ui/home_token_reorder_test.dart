import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/theme_settings.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/token_repository.dart';
import 'package:citadel_auth/platform/keystore_service.dart';
import 'package:citadel_auth/ui/screens/home_screen.dart';
import 'package:citadel_auth/ui/theme/app_theme.dart';
import 'package:citadel_auth/ui/widgets/token_card.dart';

const _secret = 'JBSWY3DPEHPK3PXP';

/// Stands in for SQLCipher, which can't run in the host test VM: holds the
/// tokens in memory and applies sort orders the way the database would.
class _FakeTokenRepository extends TokenRepository {
  _FakeTokenRepository(this.tokens) : super(VaultDatabase());

  List<Token> tokens;
  Map<String, int>? savedOrder;

  @override
  Future<void> updateSortOrders(Map<String, int> idToOrder) async {
    savedOrder = idToOrder;
    tokens = [
      for (final t in tokens) t.copyWith(sortOrder: idToOrder[t.id]),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}

class _FakeKeystore extends KeystoreService {
  Set<String>? expanded;

  @override
  Future<void> storeExpandedSections(Set<String> ids) async => expanded = ids;
}

Token _token(String issuer) =>
    Token(id: issuer, issuer: issuer, account: 'a@b.c', secret: _secret);

Future<_FakeTokenRepository> _pumpHome(
  WidgetTester tester, {
  _FakeKeystore? keystore,
  Set<String> expanded = const {},
}) async {
  final repo = _FakeTokenRepository([_token('Alpha'), _token('Bravo')]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      keystoreServiceProvider.overrideWithValue(keystore ?? _FakeKeystore()),
      expandedSectionsProvider.overrideWith((ref) => expanded),
      tokenRepositoryProvider.overrideWithValue(repo),
      tokenListProvider.overrideWith((ref) async => repo.tokens),
      searchResultsProvider.overrideWith((ref) async => repo.tokens),
      profileListProvider.overrideWith((ref) async => <Profile>[]),
      groupListProvider.overrideWith((ref) async => <TokenGroup>[]),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme(), home: const HomeScreen()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

List<String> _visibleIssuers(WidgetTester tester) => tester
    .widgetList<TokenCard>(find.byType(TokenCard))
    .map((c) => c.token.issuer)
    .toList();

void main() {
  testWidgets('sections start collapsed and open on tap', (tester) async {
    await _pumpHome(tester);
    expect(find.byType(TokenCard), findsNothing);

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(_visibleIssuers(tester), ['Alpha', 'Bravo']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('typing searches without opening anything, clearing restores',
      (tester) async {
    await _pumpHome(tester);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byType(TokenCard), findsNothing);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(_visibleIssuers(tester), ['Alpha', 'Bravo']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(TokenCard), findsNothing);
    expect(find.text('General'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening and closing a section is remembered', (tester) async {
    final keystore = _FakeKeystore();
    await _pumpHome(tester, keystore: keystore);

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    final saved = keystore.expanded!;
    expect(saved, hasLength(1));

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(keystore.expanded, isEmpty);

    // Same id, fresh app: the section comes back open.
    await tester.pumpWidget(const SizedBox());
    await _pumpHome(tester, expanded: saved);
    expect(_visibleIssuers(tester), ['Alpha', 'Bravo']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dragging a card by its handle persists the new order',
      (tester) async {
    final repo = await _pumpHome(tester);
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();

    final handle = find
        .descendant(
          of: find.byType(TokenCard),
          matching: find.byIcon(Icons.drag_indicator_rounded),
        )
        .first;
    final cardHeight = tester.getSize(find.byType(TokenCard).first).height;

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    // Small steps like a real finger; the list re-evaluates the drop slot per move.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, cardHeight / 4));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repo.savedOrder, {'Bravo': 0, 'Alpha': 1});
    expect(_visibleIssuers(tester), ['Bravo', 'Alpha']);

    await tester.pumpWidget(const SizedBox());
  });

  test('theme defaults to dark', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(citadelThemeModeProvider), CitadelThemeMode.dark);
  });

  test('Personal Theme starts from the active theme colors', () {
    final dark = CustomThemeColors.fromScheme(AppTheme.darkTheme().colorScheme);
    expect(dark.background, Colors.black);
    expect(dark.text, Colors.white);
    expect(dark.element, Colors.white);

    final light =
        CustomThemeColors.fromScheme(AppTheme.lightTheme().colorScheme);
    expect(light.background, Colors.white);
    expect(light.text, Colors.black);
    expect(light.element, Colors.black);
  });
}
