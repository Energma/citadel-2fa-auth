import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/all_view_layout.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/token.dart';

const _secret = 'JBSWY3DPEHPK3PXP';

void main() {
  final personal = Profile(id: 'p1', name: 'Personal', colorValue: 0, sortOrder: 0);
  final work = Profile(id: 'p2', name: 'Work', colorValue: 0, sortOrder: 1);
  final banks = TokenGroup(id: 'g1', profileId: 'p1', name: 'Banks');
  final dev = TokenGroup(id: 'g2', profileId: 'p2', name: 'Dev');

  test('sections default to profile order, General first in each', () {
    final ids = buildAllViewSections([work, personal], [dev, banks])
        .map((s) => s.id)
        .toList();
    expect(ids, [
      AllViewSection.generalId('p1'),
      'g1',
      AllViewSection.generalId('p2'),
      'g2',
      AllViewSection.generalId(null),
    ]);
  });

  test('tokens go to their group, else their profile General, else no-profile',
      () {
    Token token(String id, {String? profileId, String? groupId}) => Token(
        id: id,
        issuer: id,
        account: '',
        secret: _secret,
        profileId: profileId,
        groupId: groupId);

    final result = assignTokensToSections([
      token('grouped', profileId: 'p1', groupId: 'g1'),
      token('ungrouped', profileId: 'p2'),
      token('staleGroup', profileId: 'p1', groupId: 'deleted'),
      token('staleProfile', profileId: 'deleted'),
    ], buildAllViewSections([personal, work], [banks]));

    List<String> idsIn(String section) =>
        result[section]!.map((t) => t.id).toList();
    expect(idsIn('g1'), ['grouped']);
    expect(idsIn(AllViewSection.generalId('p2')), ['ungrouped']);
    expect(idsIn(AllViewSection.generalId('p1')), ['staleGroup']);
    expect(idsIn(AllViewSection.generalId(null)), ['staleProfile']);
  });

  test('arrange follows saved order and appends unknown items', () {
    const layout = AllViewLayout(order: ['c', 'a']);
    expect(layout.arrange(['a', 'b', 'c', 'd'], (s) => s), ['c', 'a', 'b', 'd']);
  });

  test('a Home-screen drag leaves hidden sections in their slots', () {
    const layout = AllViewLayout(order: ['a', 'x', 'b', 'c'], hidden: {'x'});
    final next = layout.withShownOrder(['a', 'b', 'c', 'x'], ['c', 'a', 'b']);
    expect(next.order, ['c', 'x', 'a', 'b']);
    expect(next.hidden, {'x'});
  });

  test('round-trips through storage and tolerates bad data', () {
    const layout = AllViewLayout(order: ['a', 'b'], hidden: {'b'});
    final restored = AllViewLayout.fromJsonString(layout.toJsonString());
    expect(restored.order, ['a', 'b']);
    expect(restored.hidden, {'b'});

    for (final bad in [null, 'not json', '[]', '{"order":1}']) {
      final fallback = AllViewLayout.fromJsonString(bad);
      expect(fallback.order, isEmpty);
      expect(fallback.hidden, isEmpty);
    }
  });
}
