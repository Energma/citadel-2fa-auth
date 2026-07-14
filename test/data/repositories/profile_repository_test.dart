import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/profile_repository.dart';

/// In-memory fake of [VaultDatabase] for profile/group repository tests.
/// See token_repository_test.dart for why the real SQLCipher DB can't run in
/// the host test VM.
class _FakeVaultDatabase extends VaultDatabase {
  final List<Profile> profiles = [];
  final List<TokenGroup> groups = [];
  Map<String, int>? lastProfileSortOrders;
  Map<String, int>? lastGroupSortOrders;

  @override
  Future<List<Profile>> getAllProfiles() async => List.of(profiles);

  @override
  Future<void> insertProfile(Profile profile) async => profiles.add(profile);

  @override
  Future<void> updateProfile(Profile profile) async {
    final i = profiles.indexWhere((p) => p.id == profile.id);
    if (i >= 0) profiles[i] = profile;
  }

  @override
  Future<void> deleteProfile(String id) async =>
      profiles.removeWhere((p) => p.id == id);

  @override
  Future<void> updateProfileSortOrders(Map<String, int> idToOrder) async =>
      lastProfileSortOrders = idToOrder;

  @override
  Future<List<TokenGroup>> getAllGroups() async => List.of(groups);

  @override
  Future<List<TokenGroup>> getGroupsByProfile(String profileId) async =>
      groups.where((g) => g.profileId == profileId).toList();

  @override
  Future<void> insertGroup(TokenGroup group) async => groups.add(group);

  @override
  Future<void> updateGroup(TokenGroup group) async {
    final i = groups.indexWhere((g) => g.id == group.id);
    if (i >= 0) groups[i] = group;
  }

  @override
  Future<void> deleteGroup(String id) async =>
      groups.removeWhere((g) => g.id == id);

  @override
  Future<void> updateGroupSortOrders(Map<String, int> idToOrder) async =>
      lastGroupSortOrders = idToOrder;
}

void main() {
  late _FakeVaultDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = _FakeVaultDatabase();
    repo = ProfileRepository(db);
  });

  group('Profiles', () {
    test('add / getAll / update / delete', () async {
      final p = Profile(id: 'p1', name: 'Personal', colorValue: 0xFF000000);
      await repo.add(p);
      expect((await repo.getAll()).single.name, 'Personal');

      await repo.update(p.copyWith(name: 'Renamed'));
      expect((await repo.getAll()).single.name, 'Renamed');

      await repo.delete('p1');
      expect(await repo.getAll(), isEmpty);
    });

    test('updateSortOrders forwards the map', () async {
      await repo.updateSortOrders({'p1': 0, 'p2': 1});
      expect(db.lastProfileSortOrders, {'p1': 0, 'p2': 1});
    });
  });

  group('Groups', () {
    test('add / getAll / update / delete', () async {
      final g = TokenGroup(id: 'g1', profileId: 'p1', name: 'Email');
      await repo.addGroup(g);
      expect((await repo.getAllGroups()).single.name, 'Email');

      await repo.updateGroup(g.copyWith(name: 'Mail'));
      expect((await repo.getAllGroups()).single.name, 'Mail');

      await repo.deleteGroup('g1');
      expect(await repo.getAllGroups(), isEmpty);
    });

    test('getGroupsByProfile filters by profile id', () async {
      await repo.addGroup(TokenGroup(id: 'g1', profileId: 'p1', name: 'A'));
      await repo.addGroup(TokenGroup(id: 'g2', profileId: 'p2', name: 'B'));
      final forP1 = await repo.getGroupsByProfile('p1');
      expect(forP1.single.id, 'g1');
    });

    test('updateGroupSortOrders forwards the map', () async {
      await repo.updateGroupSortOrders({'g1': 1, 'g2': 0});
      expect(db.lastGroupSortOrders, {'g1': 1, 'g2': 0});
    });
  });
}
