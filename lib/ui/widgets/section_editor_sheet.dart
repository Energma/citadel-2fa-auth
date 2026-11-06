import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import 'group_icon.dart';

/// Edits one Home section: which categories it links to as shortcuts and, for
/// a real category, its name and icon. General has no name of its own to edit.
Future<void> showSectionEditor(
  BuildContext context, {
  required String sectionId,
  TokenGroup? group,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SectionEditorSheet(sectionId: sectionId, group: group),
  );
}

class _SectionEditorSheet extends ConsumerStatefulWidget {
  final String sectionId;
  final TokenGroup? group;

  const _SectionEditorSheet({required this.sectionId, this.group});

  @override
  ConsumerState<_SectionEditorSheet> createState() =>
      _SectionEditorSheetState();
}

class _SectionEditorSheetState extends ConsumerState<_SectionEditorSheet> {
  late final _nameController = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late String? _iconName = widget.group?.iconName;
  late final Set<String> _selected = {
    ...?ref.read(sectionShortcutsProvider)[widget.sectionId],
  };
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Profile> profiles, List<TokenGroup> groups) async {
    final group = widget.group;
    final name = _nameController.text.trim();
    if (group != null && name.isEmpty) return;
    setState(() => _saving = true);

    // Stored in the order the list shows them, so the rows read the same way.
    final ordered = [
      for (final entry in _groupsByProfile(profiles, groups))
        for (final g in entry.groups)
          if (_selected.contains(g.id)) g.id,
    ];
    final shortcuts = {...ref.read(sectionShortcutsProvider)};
    ordered.isEmpty
        ? shortcuts.remove(widget.sectionId)
        : shortcuts[widget.sectionId] = ordered;
    saveSectionShortcuts(ref, shortcuts);

    if (group != null && (name != group.name || _iconName != group.iconName)) {
      await ref
          .read(profileRepositoryProvider)
          .updateGroup(group.copyWith(name: name, iconName: _iconName));
      ref.invalidate(groupListProvider);
      ref.invalidate(groupsByProfileProvider);
    }
    if (mounted) Navigator.pop(context);
  }

  List<({Profile profile, List<TokenGroup> groups})> _groupsByProfile(
    List<Profile> profiles,
    List<TokenGroup> groups,
  ) {
    final sortedProfiles = profiles.sortedBy<num>((p) => p.sortOrder);
    return [
      for (final profile in sortedProfiles)
        (
          profile: profile,
          groups: groups
              // A section linking to itself would be a dead end.
              .where(
                (g) => g.profileId == profile.id && g.id != widget.sectionId,
              )
              .sortedBy<num>((g) => g.sortOrder),
        ),
    ].where((entry) => entry.groups.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final profiles = ref.watch(profileListProvider).valueOrNull ?? [];
    final groups = ref.watch(allGroupsProvider).valueOrNull ?? [];
    final byProfile = _groupsByProfile(profiles, groups);
    final group = widget.group;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                group == null ? 'Edit General' : 'Edit ${group.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (group != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: IconButton(
                      tooltip: 'Change icon',
                      icon: groupIcon(
                        _iconName,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () async {
                        final picked = await pickGroupIcon(context);
                        if (picked != null) setState(() => _iconName = picked);
                      },
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Shortcuts',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                'Shown at the top of this section. Tapping one opens that '
                'category; its tokens stay where they are.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ),
            Flexible(
              child: byProfile.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No other categories yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final entry in byProfile) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: entry.profile.color,
                                  radius: 4,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.profile.name,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          for (final g in entry.groups)
                            CheckboxListTile(
                              dense: true,
                              value: _selected.contains(g.id),
                              secondary: groupIcon(
                                g.iconName,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(g.name),
                              onChanged: (checked) => setState(
                                () => checked!
                                    ? _selected.add(g.id)
                                    : _selected.remove(g.id),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(profiles, groups),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
