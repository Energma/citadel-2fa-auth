import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/all_view_layout.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../widgets/group_icon.dart';

/// Chooses which categories, from which profiles, the "All" tab shows and in
/// what order. Changes apply immediately, so there is nothing to save or discard.
class AllViewEditorScreen extends ConsumerWidget {
  const AllViewEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider).valueOrNull ?? <Profile>[];
    final groups = ref.watch(groupListProvider).valueOrNull ?? <TokenGroup>[];
    final tokens = ref.watch(tokenListProvider).valueOrNull ?? [];
    final layout = ref.watch(allViewLayoutProvider);
    final theme = Theme.of(context);

    // The profile-less General only means something once such tokens exist.
    final noProfileId = AllViewSection.generalId(null);
    final hasNoProfileTokens = assignTokensToSections(
            tokens, buildAllViewSections(profiles, groups))
        .containsKey(noProfileId);
    final sections = layout.arrange(
      buildAllViewSections(profiles, groups)
          .where((s) => s.id != noProfileId || hasNoProfileTokens)
          .toList(),
      (s) => s.id,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize All'),
        actions: [
          TextButton(
            onPressed: () => saveAllViewLayout(ref, const AllViewLayout()),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Choose what appears on the All tab, and drag to set the order. '
              "Profile tabs aren't affected.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
            ),
          ),
          if (profiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final profile in profiles)
                    _profileChip(ref, profile, sections, layout),
                ],
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: sections.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = sections.map((s) => s.id).toList();
                ids.insert(newIndex, ids.removeAt(oldIndex));
                saveAllViewLayout(ref, layout.withOrder(ids));
              },
              itemBuilder: (context, index) =>
                  _sectionRow(ref, theme, sections[index], index, layout),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows or hides all of one profile's categories at once.
  Widget _profileChip(WidgetRef ref, Profile profile,
      List<AllViewSection> sections, AllViewLayout layout) {
    final ids = sections
        .where((s) => s.profile?.id == profile.id)
        .map((s) => s.id)
        .toList();
    final anyVisible = ids.any(layout.isVisible);
    return FilterChip(
      avatar: CircleAvatar(backgroundColor: profile.color, radius: 5),
      label: Text(profile.name),
      selected: anyVisible,
      showCheckmark: false,
      onSelected: (_) {
        var next = layout;
        for (final id in ids) {
          next = next.withVisibility(id, !anyVisible);
        }
        saveAllViewLayout(ref, next);
      },
    );
  }

  Widget _sectionRow(WidgetRef ref, ThemeData theme, AllViewSection section,
      int index, AllViewLayout layout) {
    final visible = layout.isVisible(section.id);
    final mutedColor = theme.colorScheme.onSurface.withAlpha(140);
    return ListTile(
      key: ValueKey(section.id),
      contentPadding: const EdgeInsets.only(left: 8, right: 12),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 20, color: mutedColor),
            ),
          ),
          section.isGeneral
              ? Icon(Icons.apps_rounded, size: 20, color: mutedColor)
              : groupIcon(section.group!.iconName,
                  size: 20, color: theme.colorScheme.primary),
        ],
      ),
      title: Text(section.name),
      subtitle: Text(section.profile?.name ?? 'No profile'),
      trailing: Switch(
        value: visible,
        onChanged: (show) =>
            saveAllViewLayout(ref, layout.withVisibility(section.id, show)),
      ),
    );
  }
}
