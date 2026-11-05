import 'dart:convert';
import 'profile.dart';
import 'token.dart';

/// One entry on the "All" tab: a category from a specific profile. Each profile
/// gets its own General, so ungrouped tokens can be shown or hidden per profile.
class AllViewSection {
  final String id;
  final TokenGroup? group;
  final Profile? profile;

  const AllViewSection({required this.id, this.group, this.profile});

  bool get isGeneral => group == null;
  String get name => group?.name ?? 'General';

  static String generalId(String? profileId) =>
      '__general__:${profileId ?? 'none'}';
}

/// Every possible section in default order: profile by profile, General first.
/// Ends with the General for tokens that belong to no profile.
List<AllViewSection> buildAllViewSections(
    List<Profile> profiles, List<TokenGroup> groups) {
  final sortedGroups = groups.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final sortedProfiles = profiles.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [
    for (final profile in sortedProfiles) ...[
      AllViewSection(
          id: AllViewSection.generalId(profile.id), profile: profile),
      for (final group in sortedGroups.where((g) => g.profileId == profile.id))
        AllViewSection(id: group.id, group: group, profile: profile),
    ],
    AllViewSection(id: AllViewSection.generalId(null)),
  ];
}

/// Tokens per section id. A token whose group or profile no longer exists falls
/// through to a General, so it can never become unreachable.
Map<String, List<Token>> assignTokensToSections(
    List<Token> tokens, List<AllViewSection> sections) {
  final ids = sections.map((s) => s.id).toSet();
  final result = <String, List<Token>>{};
  for (final token in tokens) {
    final general = AllViewSection.generalId(token.profileId);
    final id = ids.contains(token.groupId)
        ? token.groupId!
        : ids.contains(general)
            ? general
            : AllViewSection.generalId(null);
    result.putIfAbsent(id, () => []).add(token);
  }
  return result;
}

/// The user's arrangement of the "All" tab. Stored separately from each group's
/// own sortOrder, so arranging All never changes the order on a profile's tab.
///
/// Only hidden ids are recorded, so a category created later shows up by default.
class AllViewLayout {
  final List<String> order;
  final Set<String> hidden;

  const AllViewLayout({this.order = const [], this.hidden = const {}});

  factory AllViewLayout.fromJsonString(String? raw) {
    if (raw == null) return const AllViewLayout();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AllViewLayout(
        order: (map['order'] as List).cast<String>().toList(),
        hidden: (map['hidden'] as List).cast<String>().toSet(),
      );
    } catch (_) {
      // A cosmetic preference isn't worth failing app start over.
      return const AllViewLayout();
    }
  }

  String toJsonString() =>
      jsonEncode({'order': order, 'hidden': hidden.toList()});

  bool isVisible(String id) => !hidden.contains(id);

  /// [items] in saved order; anything not saved yet keeps its place after them.
  List<T> arrange<T>(List<T> items, String Function(T) idOf) {
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final cmp = (rank[idOf(a.value)] ?? order.length)
            .compareTo(rank[idOf(b.value)] ?? order.length);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  AllViewLayout withVisibility(String id, bool visible) => AllViewLayout(
        order: order,
        hidden: visible ? ({...hidden}..remove(id)) : {...hidden, id},
      );

  AllViewLayout withOrder(List<String> newOrder) =>
      AllViewLayout(order: newOrder, hidden: hidden);

  /// Applies a drag on the Home screen, which only shows some of [allIds]. Those
  /// take the new sequence; the rest (hidden or empty) keep their exact slots.
  AllViewLayout withShownOrder(List<String> allIds, List<String> shownOrder) {
    final shown = shownOrder.toSet();
    final next = shownOrder.iterator;
    return withOrder([
      for (final id in arrange(allIds, (id) => id))
        if (shown.contains(id) && next.moveNext()) next.current else id,
    ]);
  }
}
