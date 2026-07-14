import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/models/profile.dart';
import '../../core/models/token.dart';
import '../../core/providers.dart';
import '../widgets/token_card.dart';
import '../widgets/master_password_dialog.dart';
import 'add_token_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  DateTime? _pausedAt;
  TabController? _tabController;
  List<Profile> _profiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final lockDuration = ref.read(autoLockDurationProvider);
      if (DateTime.now().difference(_pausedAt!) > lockDuration) {
        ref.read(vaultProvider.notifier).lock();
      }
      _pausedAt = null;
    }
  }

  void _rebuildTabs(List<Profile> profiles) {
    if (_listEquals(profiles, _profiles)) return;
    _profiles = profiles;
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: profiles.length + 1, // +1 for "All"
      vsync: this,
      initialIndex: oldIndex.clamp(0, profiles.length),
    );
    _tabController!.addListener(_onTabChanged);
  }

  bool _listEquals(List<Profile> a, List<Profile> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) return false;
    }
    return true;
  }

  void _onTabChanged() {
    if (!_tabController!.indexIsChanging) {
      final index = _tabController!.index;
      if (index == 0) {
        ref.read(activeProfileIdProvider.notifier).state = null;
      } else {
        ref.read(activeProfileIdProvider.notifier).state =
            _profiles[index - 1].id;
      }
    }
  }

  void _deleteToken(String id) async {
    // Deleting permanently loses data. A single master-password step is both
    // the confirmation and the authentication — no separate confirm dialog, so
    // the destructive warning lives here alongside the password prompt.
    await showDialog(
      context: context,
      builder: (pwdCtx) => MasterPasswordDialog(
        title: 'Delete Token',
        subtitle:
            'This permanently removes the token — you may lose access to the '
            'account if you don\'t have a backup. Enter your master password to '
            'confirm.',
        onConfirm: () async {
          await ref.read(tokenRepositoryProvider).delete(id);
          ref.invalidate(tokenListProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _isSearching
        ? ref.watch(searchResultsProvider)
        : ref.watch(tokenListProvider);
    final profiles = ref.watch(profileListProvider);
    final groups = ref.watch(groupListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return profiles.when(
      data: (profileList) {
        _rebuildTabs(profileList);
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildAppBar(theme, isDark, innerBoxIsScrolled),
            ],
            body: tokens.when(
              data: (tokenList) {
                return groups.when(
                  // Only truly empty when there are no groups either — an empty
                  // group is structure the user created and should still see.
                  data: (groupList) => tokenList.isEmpty && groupList.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildTokenList(tokenList, groupList),
                  loading: () => tokenList.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildTokenList(tokenList, []),
                  error: (_, _) => tokenList.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildTokenList(tokenList, []),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('Failed to load profiles')),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark, bool innerBoxIsScrolled) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: true,
      title: _isSearching
          ? _buildSearchField(theme)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/logo/citadel_logo.svg',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  'Citadel',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
      actions: [
        Tooltip(
          message: 'Add Key',
          child: FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Token'),
            onPressed: _openAddToken,
            style: FilledButton.styleFrom(
              // Drive both colors off the accent so the icon and label stay
              // readable on any accent, in light and dark.
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(_isSearching),
            ),
          ),
          onPressed: () {
            setState(() => _isSearching = !_isSearching);
            if (!_isSearching) {
              _searchController.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: _isSearching ? null : _buildTabBar(theme, isDark),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search tokens...',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
    );
  }

  PreferredSizeWidget _buildTabBar(ThemeData theme, bool isDark) {
    if (_tabController == null) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 25),
                ),
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withAlpha(140),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                splashBorderRadius: BorderRadius.circular(12),
                tabs: [
                  _buildTab('All', null),
                  ..._profiles.map((p) => _buildTab(p.name, p.color)),
                ],
              ),
            ),
            _buildManageButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, Color? dotColor) {
    return Tab(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        icon: Icon(
          Icons.tune_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
        tooltip: 'Manage profiles & groups',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) {
          ref.invalidate(profileListProvider);
          ref.invalidate(groupListProvider);
        }),
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }

  Widget _buildTokenList(List<Token> tokenList, List<TokenGroup> groups) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Group tokens by groupId
    final Map<String?, List<Token>> grouped = {};
    for (final t in tokenList) {
      grouped.putIfAbsent(t.groupId, () => []).add(t);
    }

    final ungrouped = grouped.remove(null) ?? <Token>[];

    // All groups (even empty ones) so user sees the structure
    final orderedGroups = groups.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // A token can reference a group we aren't showing (deleted group, or one
    // owned by another profile). Fold it into General so it can never become
    // invisible just because its section is missing.
    final shownGroupIds = orderedGroups.map((g) => g.id).toSet();
    for (final entry in grouped.entries) {
      if (!shownGroupIds.contains(entry.key)) ungrouped.addAll(entry.value);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tokenListProvider);
        ref.invalidate(groupListProvider);
      },
      child: ListView(
        padding:
            const EdgeInsets.only(top: 8, bottom: 96, left: 4, right: 4),
        children: [
          // Ungrouped tokens in a collapsible "General" section
          if (ungrouped.isNotEmpty)
            _buildGroupSection(
              theme,
              isDark,
              null,
              ungrouped,
            ),

          // Each group as a collapsible section
          for (final group in orderedGroups)
            _buildGroupSection(
              theme,
              isDark,
              group,
              grouped[group.id] ?? [],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
      ThemeData theme, bool isDark, TokenGroup? group, List<Token> tokens) {
    final isGeneral = group == null;
    final name = isGeneral ? 'General' : group.name;
    final icon = isGeneral ? Icons.apps_rounded : Icons.folder_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(6)
                : Colors.black.withAlpha(6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(10),
            ),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('group_${group?.id ?? 'general'}'),
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const RoundedRectangleBorder(),
              collapsedShape: const RoundedRectangleBorder(),
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tokens.length}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isGeneral
                        ? theme.colorScheme.onSurface.withAlpha(140)
                        : theme.colorScheme.primary.withAlpha(180),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              children: tokens.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        child: Text(
                          'No tokens in this group',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(80),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ]
                  : tokens.map((t) => _buildTokenCard(t)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenCard(Token token) {
    return TokenCard(
      key: ValueKey(token.id),
      token: token,
      onDelete: () => _deleteToken(token.id),
      onEdit: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTokenScreen(editToken: token),
          ),
        );
        ref.invalidate(tokenListProvider);
        ref.invalidate(groupListProvider);
      },
      onCounterIncrement: token.type == OtpType.hotp
          ? () async {
              final repo = ref.read(tokenRepositoryProvider);
              await repo.incrementHotpCounter(token);
              ref.invalidate(tokenListProvider);
              return token.copyWith(counter: token.counter + 1);
            }
          : null,
      onMoveToProfile: () => _showMoveDialog(token),
    );
  }

  void _showMoveDialog(Token token) async {
    final profiles = _profiles;
    final groups = ref.read(groupListProvider).valueOrNull ?? [];

    final result = await showModalBottomSheet<_MoveResult>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),

                // Profile section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Profile',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, size: 20),
                  title: const Text('None'),
                  dense: true,
                  selected: token.profileId == null,
                  onTap: () => Navigator.pop(
                      ctx, _MoveResult(profileId: '__none__')),
                ),
                ...profiles.map((p) => ListTile(
                      leading: CircleAvatar(
                          backgroundColor: p.color, radius: 8),
                      title: Text(p.name),
                      dense: true,
                      selected: token.profileId == p.id,
                      onTap: () => Navigator.pop(
                          ctx, _MoveResult(profileId: p.id)),
                    )),

                if (groups.isNotEmpty) ...[
                  const Divider(height: 20),
                  // Group section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Group',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading:
                        const Icon(Icons.remove_circle_outline, size: 20),
                    title: const Text('None'),
                    dense: true,
                    selected: token.groupId == null,
                    onTap: () => Navigator.pop(
                        ctx, _MoveResult(groupId: '__none__')),
                  ),
                  ...groups.map((g) => ListTile(
                        leading: Icon(Icons.folder_rounded,
                            size: 20,
                            color: theme.colorScheme.primary),
                        title: Text(g.name),
                        dense: true,
                        selected: token.groupId == g.id,
                        onTap: () => Navigator.pop(
                            ctx, _MoveResult(groupId: g.id)),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    final repo = ref.read(tokenRepositoryProvider);

    if (result.profileId != null) {
      final pid = result.profileId == '__none__' ? null : result.profileId;
      await repo.updateProfile(token.id, pid);
    }
    if (result.groupId != null) {
      final gid = result.groupId == '__none__' ? null : result.groupId;
      await repo.updateGroup(token.id, gid);
    }
    ref.invalidate(tokenListProvider);
  }

  Future<void> _openAddToken() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTokenScreen()),
    );
    ref.invalidate(tokenListProvider);
    ref.invalidate(groupListProvider);
  }

  Widget _buildEmptyState(ThemeData theme) {
    final activeId = ref.watch(activeProfileIdProvider);
    final profileName = activeId != null
        ? _profiles
            .where((p) => p.id == activeId)
            .map((p) => p.name)
            .firstOrNull
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: SvgPicture.asset(
                'assets/logo/citadel_logo.svg',
                width: 96,
                height: 96,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              profileName != null
                  ? 'No $profileName tokens'
                  : 'No tokens yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first 2FA token',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveResult {
  final String? profileId;
  final String? groupId;
  _MoveResult({this.profileId, this.groupId});
}
