import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../core/models/profile.dart';
import 'group_icon.dart';

/// A profile and category, always chosen as a pair: a category belongs to one
/// profile, so picking only one of them could file a token under a category
/// its profile doesn't have.
typedef TokenDestination = ({String? profileId, String? groupId});

/// Every place a token can live, one tap each: no profile, then each profile's
/// General and categories. Returns null if dismissed.
Future<TokenDestination?> pickTokenDestination(
  BuildContext context, {
  required String title,
  required List<Profile> profiles,
  required List<TokenGroup> groups,
  TokenDestination? current,
}) {
  return showModalBottomSheet<TokenDestination>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget destination(String? profileId, String? groupId, Widget leading,
              String label, {double indent = 0}) =>
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 20 + indent, right: 20),
            leading: leading,
            title: Text(label),
            trailing: current?.profileId == profileId &&
                    current?.groupId == groupId
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
            onTap: () =>
                Navigator.pop(ctx, (profileId: profileId, groupId: groupId)),
          );
      final general = Icon(Icons.apps_rounded,
          size: 20, color: theme.colorScheme.onSurface.withAlpha(140));
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              destination(null, null, general, 'No profile (All only)'),
              for (final p in profiles.sortedBy<num>((p) => p.sortOrder)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: p.color, radius: 5),
                    const SizedBox(width: 8),
                    Text(p.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                destination(p.id, null, general, 'General', indent: 12),
                for (final g in groups
                    .where((g) => g.profileId == p.id)
                    .sortedBy<num>((g) => g.sortOrder))
                  destination(
                      p.id,
                      g.id,
                      groupIcon(g.iconName,
                          size: 20, color: theme.colorScheme.primary),
                      g.name,
                      indent: 12),
              ],
            ],
          ),
        ),
      );
    },
  );
}
