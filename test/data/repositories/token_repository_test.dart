import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/token_repository.dart';

/// In-memory fake of [VaultDatabase] that records the calls the repository
/// makes, so we can assert the repository delegates correctly without a real
/// SQLCipher database (which requires a device/plugin and can't run in the
/// host test VM).
class _FakeVaultDatabase extends VaultDatabase {
  final List<String> calls = [];
  final List<Token> store = [];

  // Captured arguments for assertions.
  String? lastHotpId;
  int? lastHotpCounter;
  String? lastTokenId;
  String? lastProfileId;
  String? lastGroupId;
  List<Token>? lastInserted;

  @override
  Future<List<Token>> getAllTokens() async {
    calls.add('getAllTokens');
    return List.of(store);
  }

  @override
  Future<List<Token>> getTokensByProfile(String profileId) async {
    calls.add('getTokensByProfile');
    return store.where((t) => t.profileId == profileId).toList();
  }

  @override
  Future<void> insertToken(Token token) async {
    calls.add('insertToken');
    store.add(token);
  }

  @override
  Future<void> updateToken(Token token) async {
    calls.add('updateToken');
  }

  @override
  Future<void> deleteToken(String id) async {
    calls.add('deleteToken');
    store.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> updateHotpCounter(String tokenId, int newCounter) async {
    calls.add('updateHotpCounter');
    lastHotpId = tokenId;
    lastHotpCounter = newCounter;
  }

  @override
  Future<List<Token>> searchTokens(String query) async {
    calls.add('searchTokens');
    return store
        .where((t) => t.issuer.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<void> insertTokens(List<Token> tokens) async {
    calls.add('insertTokens');
    lastInserted = tokens;
    store.addAll(tokens);
  }

  @override
  Future<int> tokenCount() async {
    calls.add('tokenCount');
    return store.length;
  }

  @override
  Future<void> updateTokenProfile(String tokenId, String? profileId) async {
    calls.add('updateTokenProfile');
    lastTokenId = tokenId;
    lastProfileId = profileId;
  }

  @override
  Future<void> updateTokenGroup(String tokenId, String? groupId) async {
    calls.add('updateTokenGroup');
    lastTokenId = tokenId;
    lastGroupId = groupId;
  }
}

void main() {
  late _FakeVaultDatabase db;
  late TokenRepository repo;

  setUp(() {
    db = _FakeVaultDatabase();
    repo = TokenRepository(db);
  });

  test('add / getAll round-trips through the database', () async {
    final token = Token(issuer: 'GitHub', account: 'a', secret: 'S');
    await repo.add(token);
    final all = await repo.getAll();
    expect(all.single.issuer, 'GitHub');
    expect(db.calls, containsAll(['insertToken', 'getAllTokens']));
  });

  test('incrementHotpCounter writes counter + 1 for the right token', () async {
    final token = Token(
      id: 'tok-7',
      issuer: 'Bank',
      account: 'me',
      secret: 'S',
      type: OtpType.hotp,
      counter: 41,
    );
    await repo.incrementHotpCounter(token);
    expect(db.lastHotpId, 'tok-7');
    expect(db.lastHotpCounter, 42);
  });

  test('delete removes the token by id', () async {
    final token = Token(id: 'tok-1', issuer: 'X', account: 'a', secret: 'S');
    await repo.add(token);
    await repo.delete('tok-1');
    expect(await repo.getAll(), isEmpty);
  });

  test('importTokens forwards the full batch', () async {
    final tokens = [
      Token(issuer: 'A', account: '1', secret: 'S1'),
      Token(issuer: 'B', account: '2', secret: 'S2'),
    ];
    await repo.importTokens(tokens);
    expect(db.lastInserted, hasLength(2));
    expect(await repo.count(), 2);
  });

  test('search delegates the query to the database', () async {
    await repo.add(Token(issuer: 'GitHub', account: 'a', secret: 'S'));
    await repo.add(Token(issuer: 'GitLab', account: 'b', secret: 'S'));
    final hits = await repo.search('github');
    expect(hits, hasLength(1));
    expect(hits.single.issuer, 'GitHub');
  });

  test('updateProfile / updateGroup pass through ids (including null)', () async {
    await repo.updateProfile('tok-1', 'prof-9');
    expect(db.lastTokenId, 'tok-1');
    expect(db.lastProfileId, 'prof-9');

    await repo.updateGroup('tok-1', null);
    expect(db.lastTokenId, 'tok-1');
    expect(db.lastGroupId, isNull);
  });
}
