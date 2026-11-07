import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/models/profile.dart';
import '../../core/models/token.dart';
import '../../core/providers.dart';
import '../theme/palette.dart';
import '../widgets/group_icon.dart';
import '../widgets/master_password_dialog.dart';
import '../widgets/service_icon.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  /// Opens straight on this profile's groups, e.g. from its Home tab.
  final String? initialProfileId;

  const ProfileScreen({super.key, this.initialProfileId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String? _selectedProfileIdForGroups = widget.initialProfileId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialProfileId == null ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles & Groups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profiles'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProfileTab(ref: ref, onProfileSelected: (profileId) {
            setState(() => _selectedProfileIdForGroups = profileId);
          }),
          _GroupTab(
            ref: ref,
            selectedProfileId: _selectedProfileIdForGroups,
            onProfileSelected: (profileId) {
              setState(() => _selectedProfileIdForGroups = profileId);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Profiles Tab ───

class _ProfileTab extends ConsumerWidget {
  final WidgetRef ref;
  final ValueChanged<String>? onProfileSelected;
  const _ProfileTab({required this.ref, this.onProfileSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider);

    return profiles.when(
      data: (list) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showProfileDialog(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Profile'),
                  ),
                ),
              ),
              if (list.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(60)),
                        const SizedBox(height: 12),
                        Text('No profiles',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(100),
                                )),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                    itemCount: list.length,
                    onReorder: (old, newIdx) =>
                        _reorderProfiles(ref, list, old, newIdx),
                    itemBuilder: (context, index) {
                      final p = list[index];
                      return Card(
                        key: ValueKey(p.id),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: p.color),
                          title: Text(p.name),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') {
                                _showProfileDialog(context, ref, p);
                              }
                              if (v == 'delete') {
                                _deleteProfile(context, ref, p);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _reorderProfiles(
      WidgetRef ref, List<Profile> list, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final orders = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      orders[list[i].id] = i;
    }
    await ref.read(profileRepositoryProvider).updateSortOrders(orders);
    ref.invalidate(profileListProvider);
  }

  void _showProfileDialog(
      BuildContext context, WidgetRef ref, Profile? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    int selectedColor =
        existing?.colorValue ?? Palette.profileColors[0].toARGB32();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Profile' : 'Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g. Personal, Work',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(80),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(60),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Color',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Palette.profileColors.map((c) {
                  final isSelected = c.toARGB32() == selectedColor;
                  return GestureDetector(
                    onTap: () => setDialogState(
                        () => selectedColor = c.toARGB32()),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface,
                                width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                // Adding and editing are non-destructive — no master password.
                Future<void> persist() async {
                  final repo = ref.read(profileRepositoryProvider);
                  if (existing != null) {
                    await repo.update(existing.copyWith(
                      name: name,
                      colorValue: selectedColor,
                    ));
                  } else {
                    await repo.add(Profile(
                      name: name,
                      colorValue: selectedColor,
                    ));
                  }
                  ref.invalidate(profileListProvider);
                }

                persist();
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
            'Delete "${profile.name}"? Tokens in this profile will be unassigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => MasterPasswordDialog(
          onConfirm: () async {
            await ref.read(profileRepositoryProvider).delete(profile.id);
            ref.invalidate(profileListProvider);
          },
        ),
      );
    }
  }
}

// ─── Groups Tab ───

class _GroupTab extends ConsumerWidget {
  final WidgetRef ref;
  final String? selectedProfileId;
  final ValueChanged<String>? onProfileSelected;
  const _GroupTab({
    required this.ref,
    this.selectedProfileId,
    this.onProfileSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider);
    final theme = Theme.of(context);

    return profiles.when(
      data: (profileList) {
        final currentProfileId = selectedProfileId ?? profileList.firstOrNull?.id;
        if (currentProfileId == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withAlpha(60)),
                const SizedBox(height: 12),
                Text('No profiles',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    )),
              ],
            ),
          );
        }

        final currentProfile =
            profileList.firstWhereOrNull((p) => p.id == currentProfileId);

        return Column(
          children: [
            if (profileList.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showProfilePicker(
                      context, profileList, currentProfileId, onProfileSelected),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Profile',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withAlpha(60),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                    child: Row(
                      children: [
                        if (currentProfile != null) ...[
                          CircleAvatar(
                              backgroundColor: currentProfile.color, radius: 6),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: Text(currentProfile?.name ?? '')),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: theme.colorScheme.onSurface.withAlpha(140)),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _buildGroupsList(
                  context, ref, currentProfileId, theme, profileList),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showProfilePicker(BuildContext context, List<Profile> profileList,
      String? current, ValueChanged<String>? onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Profile',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    // Caps visible rows at 6 — with more options than that,
                    // the list scrolls instead of overflowing the sheet.
                    constraints: const BoxConstraints(maxHeight: 6 * 56.0),
                    child: ListView(
                      shrinkWrap: true,
                      children: profileList.map((p) => ListTile(
                            leading: CircleAvatar(
                                backgroundColor: p.color, radius: 6),
                            title: Text(p.name),
                            trailing: p.id == current
                                ? Icon(Icons.check_rounded,
                                    color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              onSelected?.call(p.id);
                              Navigator.pop(ctx);
                            },
                          )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(BuildContext context, WidgetRef ref,
      String profileId, ThemeData theme, List<Profile> profileList) {
    final profile =
        profileList.firstWhereOrNull((p) => p.id == profileId);
    if (profile == null) return const SizedBox.shrink();

    final tokens =
        ref.watch(tokensByProfileProvider(profileId)).valueOrNull ?? const [];

    return ref.watch(groupsByProfileProvider(profileId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        final groupIds = list.map((g) => g.id).toSet();
        List<Token> tokensIn(String? groupId) => tokens
            .where((t) => groupId == null
                // A token pointing at a deleted group is in General.
                ? !groupIds.contains(t.groupId)
                : t.groupId == groupId)
            .sortedBy<num>((t) => t.sortOrder);
        final general = _GroupTokens(
          title: 'General',
          icon: Icon(Icons.apps_rounded, color: theme.colorScheme.primary),
          tokens: tokensIn(null),
          tokensIn: tokensIn,
          groups: list,
          profileId: profileId,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _showGroupDialog(context, ref, null, profileId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Group'),
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
                // Only the handle drags a group, so the token rows inside an
                // open group keep their own drag and tap gestures.
                buildDefaultDragHandles: false,
                header: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No groups in ${profile.name} yet. Add one to '
                          'organize its tokens into categories.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      )
                    : null,
                // General is where ungrouped tokens live; it has no place in
                // the group order, so it sits after the groups.
                footer: general,
                itemCount: list.length,
                onReorder: (old, newIdx) =>
                    _reorderGroups(ref, list, old, newIdx),
                itemBuilder: (context, index) {
                  final g = list[index];
                  return _GroupTokens(
                    key: ValueKey(g.id),
                    title: g.name,
                    icon: groupIcon(g.iconName,
                        size: 24, color: theme.colorScheme.primary),
                    group: g,
                    tokens: tokensIn(g.id),
                    tokensIn: tokensIn,
                    groups: list,
                    profileId: profileId,
                    menu: PopupMenuButton(
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Rename')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') {
                          _showGroupDialog(context, ref, g, profileId);
                        }
                        if (v == 'delete') {
                          _deleteGroup(context, ref, g);
                        }
                      },
                    ),
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_indicator_rounded,
                          color: theme.colorScheme.onSurface.withAlpha(100)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reorderGroups(WidgetRef ref, List<TokenGroup> list,
      int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final orders = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      orders[list[i].id] = i;
    }
    await ref
        .read(profileRepositoryProvider)
        .updateGroupSortOrders(orders);
    ref.invalidate(groupListProvider);
    ref.invalidate(groupsByProfileProvider);
  }

  void _showGroupDialog(BuildContext context, WidgetRef ref,
      TokenGroup? existing, String profileId) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final theme = Theme.of(context);
    var selectedIcon = existing?.iconName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Group' : 'Rename Group'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. Social, Banking, Dev',
              prefixIcon: InkWell(
                onTap: () async {
                  final picked = await pickGroupIcon(ctx);
                  if (picked != null) setState(() => selectedIcon = picked);
                },
                child: groupIcon(selectedIcon, color: theme.colorScheme.primary),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(80),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(60),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                // Adding and renaming are non-destructive — no master password.
                // Awaited, not fire-and-forget: a swallowed database error would
                // otherwise close the dialog as if the group had been saved.
                final repo = ref.read(profileRepositoryProvider);
                if (existing != null) {
                  await repo.updateGroup(
                      existing.copyWith(name: name, iconName: selectedIcon));
                } else {
                  await repo.addGroup(TokenGroup(
                    profileId: profileId,
                    name: name,
                    iconName: selectedIcon,
                  ));
                }
                // Both: the home list and the per-profile list on this screen.
                ref.invalidate(groupListProvider);
                ref.invalidate(groupsByProfileProvider);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGroup(
      BuildContext context, WidgetRef ref, TokenGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
            'Delete "${group.name}"? Tokens in this group will become ungrouped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => MasterPasswordDialog(
          onConfirm: () async {
            await ref.read(profileRepositoryProvider).deleteGroup(group.id);
            ref.invalidate(groupListProvider);
            ref.invalidate(groupsByProfileProvider);
          },
        ),
      );
    }
  }
}

// ─── Tokens inside a group ───

/// One group on the Groups tab, opened to show its tokens. Tokens are moved
/// by dragging: drop one on a group to put it last there, or on a token to put
/// it right before that token, which also reorders within a group. The move
/// button does the same for anyone who can't or won't drag.
class _GroupTokens extends ConsumerStatefulWidget {
  final String title;
  final Widget icon;

  /// Null for General, which holds the profile's ungrouped tokens.
  final TokenGroup? group;
  final List<Token> tokens;
  final List<Token> Function(String? groupId) tokensIn;
  final List<TokenGroup> groups;
  final String profileId;
  final Widget? menu;
  final Widget? dragHandle;

  const _GroupTokens({
    super.key,
    required this.title,
    required this.icon,
    this.group,
    required this.tokens,
    required this.tokensIn,
    required this.groups,
    required this.profileId,
    this.menu,
    this.dragHandle,
  });

  @override
  ConsumerState<_GroupTokens> createState() => _GroupTokensState();
}

class _GroupTokensState extends ConsumerState<_GroupTokens> {
  bool _expanded = false;

  bool _isHere(Token token) => widget.tokens.any((t) => t.id == token.id);

  Future<void> _move(Token token, {String? toGroupId, Token? before}) async {
    final order = widget
        .tokensIn(toGroupId)
        .where((t) => t.id != token.id)
        .toList();
    final at = before == null
        ? order.length
        : order.indexWhere((t) => t.id == before.id);
    order.insert(at < 0 ? order.length : at, token);

    final repo = ref.read(tokenRepositoryProvider);
    if (token.groupId != toGroupId) await repo.updateGroup(token.id, toGroupId);
    await repo.updateSortOrders({
      for (var i = 0; i < order.length; i++) order[i].id: i,
    });
    ref.invalidate(tokensByProfileProvider(widget.profileId));
    ref.invalidate(tokenListProvider);
  }

  Future<void> _showMoveSheet(Token token) async {
    final theme = Theme.of(context);
    // The choice is wrapped in a record so General (id null) differs from a
    // dismissed sheet (null).
    final picked = await showModalBottomSheet<({String? id})>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget option(String? id, Widget icon, String name) => ListTile(
              leading: icon,
              title: Text(name),
              trailing: id == widget.group?.id
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, (id: id)),
            );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Move ${token.issuer} to',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              for (final g in widget.groups)
                option(
                    g.id,
                    groupIcon(g.iconName, color: theme.colorScheme.primary),
                    g.name),
              option(
                  null,
                  Icon(Icons.apps_rounded, color: theme.colorScheme.primary),
                  'General'),
            ],
          ),
        );
      },
    );
    if (picked != null && picked.id != widget.group?.id) {
      await _move(token, toGroupId: picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.tokens.length;

    return DragTarget<Token>(
      onWillAcceptWithDetails: (d) => !_isHere(d.data),
      onAcceptWithDetails: (d) => _move(d.data, toGroupId: widget.group?.id),
      builder: (context, hovering, _) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hovering.isNotEmpty
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              leading: widget.icon,
              title: Text(widget.title),
              subtitle: Text(
                hovering.isNotEmpty
                    ? 'Drop to move here'
                    : '$count ${count == 1 ? 'token' : 'tokens'}',
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.menu,
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurface.withAlpha(120)),
                  ),
                  if (widget.dragHandle != null) ...[
                    const SizedBox(width: 4),
                    widget.dragHandle!,
                  ],
                ],
              ),
            ),
            if (_expanded)
              if (widget.tokens.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Drag a token here',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(120)),
                  ),
                )
              else
                for (final token in widget.tokens) _buildToken(theme, token),
            if (_expanded) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildToken(ThemeData theme, Token token) {
    final row = ListTile(
      dense: true,
      leading: ServiceIcon(
        issuer: token.issuer,
        account: token.account,
        iconPath: token.iconPath,
        size: 32,
      ),
      title: Text(token.issuer.isEmpty ? token.account : token.issuer,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: token.issuer.isEmpty
          ? null
          : Text(token.account, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            tooltip: 'Move ${token.issuer}',
            onPressed: () => _showMoveSheet(token),
          ),
          Icon(Icons.drag_indicator_rounded,
              color: theme.colorScheme.onSurface.withAlpha(100)),
        ],
      ),
    );

    return DragTarget<Token>(
      onWillAcceptWithDetails: (d) => d.data.id != token.id,
      onAcceptWithDetails: (d) =>
          _move(d.data, toGroupId: widget.group?.id, before: token),
      builder: (context, hovering, _) => Column(
        children: [
          // Where the dropped token will land: just above this one.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: hovering.isNotEmpty ? 3 : 0,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: theme.colorScheme.primary,
          ),
          LongPressDraggable<Token>(
            data: token,
            hapticFeedbackOnStart: true,
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 280, child: row),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: row),
            child: row,
          ),
        ],
      ),
    );
  }
}
