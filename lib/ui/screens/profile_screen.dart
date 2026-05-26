import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../theme/palette.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          _ProfileTab(ref: ref),
          _GroupTab(ref: ref),
        ],
      ),
    );
  }
}

// ─── Profiles Tab ───

class _ProfileTab extends ConsumerWidget {
  final WidgetRef ref;
  const _ProfileTab({required this.ref});

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
                    padding: const EdgeInsets.all(16),
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
                  hintText: 'Profile name',
                  prefixIcon: const Icon(Icons.person_outline),
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

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
                if (ctx.mounted) Navigator.pop(ctx);
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

    if (confirmed == true) {
      await ref.read(profileRepositoryProvider).delete(profile.id);
      ref.invalidate(profileListProvider);
    }
  }
}

// ─── Groups Tab ───

class _GroupTab extends ConsumerWidget {
  final WidgetRef ref;
  const _GroupTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupListProvider);
    final theme = Theme.of(context);

    return groups.when(
      data: (list) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showGroupDialog(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Group'),
                  ),
                ),
              ),
              if (list.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(60)),
                        const SizedBox(height: 12),
                        Text(
                          'No groups',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            'Organize tokens into categories',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(80),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    onReorder: (old, newIdx) =>
                        _reorderGroups(ref, list, old, newIdx),
                    itemBuilder: (context, index) {
                      final g = list[index];
                      return Card(
                        key: ValueKey(g.id),
                        child: ListTile(
                          leading: Icon(Icons.folder_rounded,
                              color: theme.colorScheme.primary),
                          title: Text(g.name),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Rename')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete')),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') {
                                _showGroupDialog(context, ref, g);
                              }
                              if (v == 'delete') {
                                _deleteGroup(context, ref, g);
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
  }

  void _showGroupDialog(
      BuildContext context, WidgetRef ref, TokenGroup? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Group' : 'Rename Group'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Group name',
            prefixIcon: const Icon(Icons.folder_outlined),
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

              final repo = ref.read(profileRepositoryProvider);
              if (existing != null) {
                await repo.updateGroup(existing.copyWith(name: name));
              } else {
                await repo.addGroup(TokenGroup(name: name));
              }
              ref.invalidate(groupListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
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

    if (confirmed == true) {
      await ref.read(profileRepositoryProvider).deleteGroup(group.id);
      ref.invalidate(groupListProvider);
    }
  }
}
