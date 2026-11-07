import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/models/all_view_layout.dart';
import '../../core/models/profile.dart';
import '../../core/models/token.dart';
import '../../core/providers.dart';
import '../widgets/citadel_logo.dart';
import '../widgets/token_card.dart';
import '../widgets/group_icon.dart';
import '../widgets/master_password_dialog.dart';
import '../widgets/move_tokens_sheet.dart';
import '../widgets/service_icon.dart';
import 'add_token_screen.dart';
import 'all_view_editor_screen.dart';
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

  // Section order set by a just-completed drag, kept until the DB write and
  // provider refetch land. orderedSections is recomputed fresh from provider
  // data on every build, so without this override any unrelated rebuild that
  // happens mid-persist (NestedScrollView, another watched provider, ...)
  // would momentarily show the pre-drag order again — a visible flicker.
  List<String>? _optimisticSectionOrder;

  // Same idea for token drags, per section: sectionId -> token ids in drop order.
  final Map<String, List<String>> _optimisticTokenOrder = {};

  // Sections the user opened. Everything starts collapsed. Only tracked so the
  // chevron can follow the tile, since a custom trailing replaces its own.

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
    // _profiles starts as [] (see field declaration), so a cold start with
    // zero profiles would otherwise match on the very first call and skip
    // creating the controller entirely — permanently hiding the tab bar
    // (and its "manage profiles & groups" button) for the rest of this
    // widget's life, since nothing else ever retries the creation.
    if (_tabController != null && _listEquals(profiles, _profiles)) return;
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
          bottomNavigationBar:
              _isSearching ? null : _buildTabBar(theme, isDark),
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CitadelLogo(size: 32),
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _buildSearchField(theme),
        ),
      ),
      actions: [
        Tooltip(
          message: 'Add Key',
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Token'),
            onPressed: _openAddToken,
            style: OutlinedButton.styleFrom(
              // Accent-colored outline and content on the app background, so
              // the button follows both the accent and light/dark theme.
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _setSearch(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    setState(() => _isSearching = query.isNotEmpty);
  }

  Widget _buildSearchField(ThemeData theme) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: theme.colorScheme.onSurface.withAlpha(40)),
    );
    return TextField(
      controller: _searchController,
      style: theme.textTheme.bodyLarge,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search tokens...',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _isSearching
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  _setSearch('');
                },
              )
            : null,
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
      onChanged: _setSearch,
    );
  }

  Widget _buildTabBar(ThemeData theme, bool isDark) {
    if (_tabController == null) return const SizedBox.shrink();

    // Bottom bar sits above the OS gesture/nav area — SafeArea keeps the
    // tabs and manage button clear of it instead of letting them get
    // covered by the native navigation buttons.
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onSurface.withAlpha(15),
            ),
          ),
        ),
        padding: const EdgeInsets.only(top: 4),
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
                // TabBar's default indicator rect sits a couple pixels lower
                // than center (more gap above the label than below) — nudge
                // it up so the selected pill's padding is symmetrical.
                indicatorPadding: const EdgeInsets.only(top: -2, bottom: 2),
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
            if (ref.watch(activeProfileIdProvider) == null)
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                tooltip: 'Customize All',
                onPressed: _openAllViewEditor,
              ),
            _buildManageButton(theme),
          ],
        ),
      ),
    );
  }

  void _openAllViewEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllViewEditorScreen()),
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
          Icons.edit_outlined,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
        tooltip: 'Edit profiles & groups',
        // From a profile's tab, straight to that profile's groups and tokens.
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
                initialProfileId: ref.read(activeProfileIdProvider)),
          ),
        ).then((_) {
          ref.invalidate(profileListProvider);
          ref.invalidate(groupListProvider);
          // Tokens may have moved between groups there.
          ref.invalidate(tokenListProvider);
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
    final activeProfileId = ref.watch(activeProfileIdProvider);

    // Search keeps the simple grouping below: it has to reach everything,
    // including sections the All layout hides.
    if (activeProfileId == null && !_isSearching) {
      return _buildAllView(theme, isDark, tokenList, groups);
    }

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
    var foldedAny = false;
    for (final entry in grouped.entries) {
      if (!shownGroupIds.contains(entry.key)) {
        ungrouped.addAll(entry.value);
        foldedAny = true;
      }
    }
    // Appending put folded tokens last regardless of their saved position, which
    // would undo a drag on the next rebuild. Search keeps its own relevance order.
    if (foldedAny && !_isSearching) {
      mergeSort<Token>(ungrouped,
          compare: (a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // General's position is scoped like a group's own sortOrder, per profile.
    // Read profiles fresh from the provider rather than the _profiles field —
    // _rebuildTabs only refreshes that field when a profile's id/name changes
    // (it exists to avoid needlessly recreating the TabController), so it can
    // hold a stale generalSortOrder right after this exact reorder persists.
    final int generalOrder = ref
            .watch(profileListProvider)
            .valueOrNull
            ?.firstWhereOrNull((p) => p.id == activeProfileId)
            ?.generalSortOrder ??
        -1;

    // Same id the All tab uses, so this General's open state carries over
    // between the two.
    final sections = <_SectionData>[
      if (ungrouped.isNotEmpty)
        _SectionData(
            group: null,
            tokens: ungrouped,
            id: AllViewSection.generalId(activeProfileId)),
      for (final group in orderedGroups)
        _SectionData(group: group, tokens: grouped[group.id] ?? []),
    ];

    // Sort stably (with an index tiebreak) — new groups and General can
    // share the same default order value, and List.sort isn't guaranteed
    // stable, so without the tiebreak untouched sections could visibly
    // reshuffle between rebuilds.
    final indexed = sections.asMap().entries.toList()
      ..sort((a, b) {
        int orderOf(_SectionData s) =>
            s.isGeneral ? generalOrder : s.group!.sortOrder;
        final cmp = orderOf(a.value).compareTo(orderOf(b.value));
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    final naturalOrder = indexed.map((e) => e.value).toList();

    // Prefer the just-set drag order over whatever this build recomputed
    // from provider data, until persistence confirms it. Falls back to
    // naturalOrder on its own if the section set changed underneath it
    // (group added/deleted elsewhere) so it can never show something stale.
    final override = _optimisticSectionOrder;
    final displaySections = override != null &&
            override.length == naturalOrder.length &&
            override.every((id) => naturalOrder.any((s) => s.sectionId == id))
        ? [
            for (final id in override)
              naturalOrder.firstWhere((s) => s.sectionId == id)
          ]
        : naturalOrder;

    return _buildSectionList(theme, isDark, displaySections);
  }

  /// The "All" tab: each visible category labeled with its profile, arranged by
  /// [allViewLayoutProvider].
  Widget _buildAllView(ThemeData theme, bool isDark, List<Token> tokenList,
      List<TokenGroup> groups) {
    final profiles = ref.watch(profileListProvider).valueOrNull ?? _profiles;
    final layout = ref.watch(allViewLayoutProvider);
    final all = buildAllViewSections(profiles, groups);
    final tokensById = assignTokensToSections(tokenList, all);

    final shown = [
      for (final section in layout.arrange(all, (s) => s.id))
        // A General with nothing in it is noise; an empty group is structure
        // the user created, so it stays.
        if (layout.isVisible(section.id) &&
            (!section.isGeneral || tokensById.containsKey(section.id)))
          _SectionData(
            id: section.id,
            group: section.group,
            profile: section.profile,
            tokens: tokensById[section.id] ?? [],
          ),
    ];

    if (shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing selected for All',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _openAllViewEditor,
              child: const Text('Customize All'),
            ),
          ],
        ),
      );
    }
    return _buildSectionList(theme, isDark, shown);
  }

  Widget _buildSectionList(
      ThemeData theme, bool isDark, List<_SectionData> displaySections) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tokenListProvider);
        ref.invalidate(groupListProvider);
      },
      child: ReorderableListView.builder(
        padding:
            const EdgeInsets.only(top: 8, bottom: 96, left: 4, right: 4),
        buildDefaultDragHandles: false,
        itemCount: displaySections.length,
        onReorder: (oldIndex, newIndex) =>
            _reorderSections(displaySections, oldIndex, newIndex),
        itemBuilder: (context, index) {
          final section = displaySections[index];
          return KeyedSubtree(
            key: ValueKey('section_${section.sectionId}'),
            child: _buildGroupSection(theme, isDark, section,
                _displayTokens(section.sectionId, section.tokens), index),
          );
        },
      ),
    );
  }

  Future<void> _reorderSections(
      List<_SectionData> sections, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<_SectionData>.from(sections);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final activeProfileId = ref.read(activeProfileIdProvider);
    if (activeProfileId == null) {
      final allIds = buildAllViewSections(
        ref.read(profileListProvider).valueOrNull ?? _profiles,
        ref.read(groupListProvider).valueOrNull ?? [],
      ).map((s) => s.id).toList();
      saveAllViewLayout(
        ref,
        ref.read(allViewLayoutProvider).withShownOrder(
            allIds, reordered.map((s) => s.sectionId).toList()),
      );
      return;
    }

    // Show the drop result immediately and keep it stable until persistence
    // completes — see _optimisticSectionOrder's declaration for why this is
    // necessary rather than just mutating the rendered list in place.
    setState(() {
      _optimisticSectionOrder = reordered.map((s) => s.sectionId).toList();
    });

    final groupOrders = <String, int>{};
    int? newGeneralOrder;
    for (var i = 0; i < reordered.length; i++) {
      final section = reordered[i];
      if (section.isGeneral) {
        newGeneralOrder = i;
      } else {
        groupOrders[section.group!.id] = i;
      }
    }

    final repo = ref.read(profileRepositoryProvider);
    final writes = <Future<void>>[
      if (groupOrders.isNotEmpty) repo.updateGroupSortOrders(groupOrders),
    ];

    var touchedProfiles = false;
    if (newGeneralOrder != null) {
      writes.add(repo.updateGeneralSortOrder(activeProfileId, newGeneralOrder));
      touchedProfiles = true;
    }

    await Future.wait(writes);

    ref.invalidate(groupsByProfileProvider);

    // Wait for the refetches so provider data matches the override before
    // dropping it below — clearing it any earlier would show a stale,
    // pre-drag order for a frame until these land.
    final _ = await ref.refresh(groupListProvider.future);
    if (touchedProfiles) {
      final _ = await ref.refresh(profileListProvider.future);
    }

    if (mounted) setState(() => _optimisticSectionOrder = null);
  }

  /// [tokens] in the just-dropped order while it persists, unless the section's
  /// tokens changed underneath it (added/deleted elsewhere).
  List<Token> _displayTokens(String sectionId, List<Token> tokens) {
    final override = _optimisticTokenOrder[sectionId];
    if (override == null || override.length != tokens.length) return tokens;
    final byId = {for (final t in tokens) t.id: t};
    if (!override.every(byId.containsKey)) return tokens;
    return [for (final id in override) byId[id]!];
  }

  /// Puts [token] into [section] next to [target] (after it when [after]),
  /// or last when [target] is null. One drag covers both jobs: reordering
  /// within a section and moving to another profile or category.
  Future<void> _placeToken(Token token, _SectionData section,
      {Token? target, bool after = false}) async {
    if (token.id == target?.id) return;
    final sectionId = section.sectionId;
    final order = _displayTokens(sectionId, section.tokens)
        .where((t) => t.id != token.id)
        .toList();
    var at = target == null
        ? order.length
        : order.indexWhere((t) => t.id == target.id);
    if (at < 0) at = order.length;
    if (target != null && after) at++;
    order.insert(at, token);

    final moving = !section.tokens.any((t) => t.id == token.id);
    // Same section: show the new order now and hold it until it's saved.
    // Another section: the token disappears from its old place on refresh.
    if (!moving) {
      setState(() {
        _optimisticTokenOrder[sectionId] = order.map((t) => t.id).toList();
      });
    }
    try {
      if (moving) {
        final to = _destinationOf(section);
        await _moveToken(token, to.profileId, to.groupId, refresh: false);
      }
      await ref.read(tokenRepositoryProvider).updateSortOrders({
        for (var i = 0; i < order.length; i++) order[i].id: i,
      });
      final _ = await ref.refresh(tokenListProvider.future);
    } finally {
      // Also on failure: a kept override would hide the real order indefinitely.
      if (mounted) setState(() => _optimisticTokenOrder.remove(sectionId));
    }
  }

  /// Which token the dragged card is over, and whether it would land after it.
  ({String id, bool after})? _dropHint;

  /// The section's cards. Each is also a drop spot: the top half of a card
  /// places the dragged one before it, the bottom half after it. Search
  /// results are a filtered subset, so they stay a plain, fixed list.
  List<Widget> _buildSectionTokens(_SectionData section, List<Token> tokens) {
    if (_isSearching) return tokens.map((t) => _buildTokenCard(t)).toList();
    final theme = Theme.of(context);
    Widget line(bool show) => AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: show ? 3 : 0,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    bool afterHalf(BuildContext target, Offset pointer) {
      final box = target.findRenderObject() as RenderBox?;
      if (box == null) return false;
      return box.globalToLocal(pointer).dy > box.size.height / 2;
    }

    return [
      for (final token in tokens)
        Builder(
          key: ValueKey('drop_${token.id}'),
          builder: (target) => DragTarget<Token>(
            onWillAcceptWithDetails: (d) => d.data.id != token.id,
            onMove: (d) {
              final hint = (id: token.id, after: afterHalf(target, d.offset));
              if (hint != _dropHint) setState(() => _dropHint = hint);
            },
            onLeave: (_) {
              if (_dropHint?.id == token.id) setState(() => _dropHint = null);
            },
            onAcceptWithDetails: (d) {
              final after = afterHalf(target, d.offset);
              setState(() => _dropHint = null);
              _placeToken(d.data, section, target: token, after: after);
            },
            builder: (context, hovering, _) {
              final hint = hovering.isNotEmpty && _dropHint?.id == token.id
                  ? _dropHint
                  : null;
              return Column(children: [
                line(hint != null && !hint.after),
                _buildTokenCard(token),
                line(hint != null && hint.after),
              ]);
            },
          ),
        ),
    ];
  }

  Widget _buildGroupSection(ThemeData theme, bool isDark, _SectionData section,
      List<Token> tokens, int index) {
    final group = section.group;
    final isGeneral = group == null;
    final name = isGeneral ? 'General' : group.name;
    final sectionId = section.sectionId;
    // Search opens every section and locks it, or matches would stay hidden
    // inside collapsed ones.
    final isExpanded = _isSearching ||
        ref.watch(expandedSectionsProvider).contains(sectionId);
    final leadingIconColor = isGeneral
        ? theme.colorScheme.onSurface.withAlpha(140)
        : theme.colorScheme.primary.withAlpha(180);
    final leadingIcon = isGeneral
        ? Icon(Icons.apps_rounded, size: 18, color: leadingIconColor)
        : groupIcon(group.iconName, size: 18, color: leadingIconColor);

    return DragTarget<Token>(
      // Dropping on the header moves a token here from elsewhere, last in
      // line. Within a section the cards place it, so letting go over its
      // own section isn't a drop, and opens the move sheet instead.
      onWillAcceptWithDetails: (d) =>
          !section.tokens.any((t) => t.id == d.data.id),
      onAcceptWithDetails: (d) => _placeToken(d.data, section),
      builder: (context, hovering, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hovering.isNotEmpty
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          color: hovering.isNotEmpty
              ? theme.colorScheme.primary.withAlpha(20)
              : Colors.transparent,
        ),
        child: _buildSectionBody(theme, isDark, section, tokens, index,
            name: name,
            leadingIcon: leadingIcon,
            isExpanded: isExpanded),
      ),
    );
  }

  Widget _buildSectionBody(ThemeData theme, bool isDark, _SectionData section,
      List<Token> tokens, int index,
      {required String name,
      required Widget leadingIcon,
      required bool isExpanded}) {
    final sectionId = section.sectionId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Separate key while searching so entering search rebuilds the tile
          // expanded, and leaving it restores what the user had open.
          key: PageStorageKey(
              '${_isSearching ? 'search' : 'group'}_$sectionId'),
          initiallyExpanded: isExpanded,
          enabled: !_isSearching,
          dense: true,
          onExpansionChanged: (expanded) {
            final open = {...ref.read(expandedSectionsProvider)};
            expanded ? open.add(sectionId) : open.remove(sectionId);
            saveExpandedSections(ref, open);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              if (!_isSearching) ...[
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(width: 8),
                // Explicit drag handle — buildDefaultDragHandles is off so
                // only this triggers a drag, leaving the tile's own
                // tap-to-expand gesture untouched.
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ],
            ],
          ),
          title: Row(
            children: [
              leadingIcon,
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withAlpha(200),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              // Only the All tab mixes profiles, so only it needs the label.
              if (section.profile case final profile?) ...[
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: profile.color, radius: 3),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            if (tokens.isNotEmpty)
              ..._buildSectionTokens(section, tokens)
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  'No tokens in this group',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(80),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Where the finger went down, to tell a drag from a press-and-release.
  Offset? _pointerDown;

  /// What follows the finger while a card is dragged.
  Widget _dragFeedback(Token token) {
    final theme = Theme.of(context);
    return Transform.translate(
      offset: const Offset(-40, -28),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
          ),
          child: Row(children: [
            ServiceIcon(
              issuer: token.issuer,
              account: token.account,
              iconPath: token.iconPath,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                token.issuer.isEmpty ? token.account : token.issuer,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// A card can be picked up two ways: right away by its handle, or by
  /// holding it anywhere. Drop it on a card or a section to place it there.
  /// Holding and letting go without moving opens the move sheet instead,
  /// which also reaches sections scrolled out of view.
  Widget _buildTokenCard(Token token) {
    if (_isSearching) return _buildTokenCardBody(token);
    final theme = Theme.of(context);
    final handle = Draggable<Token>(
      data: token,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _dragFeedback(token),
      onDragEnd: (_) => _clearDropHint(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
    );
    final card = _buildTokenCardBody(token, dragHandle: handle);
    return Listener(
      key: ValueKey('drag_${token.id}'),
      onPointerDown: (e) => _pointerDown = e.position,
      child: LongPressDraggable<Token>(
        data: token,
        hapticFeedbackOnStart: true,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragEnd: (details) {
          _clearDropHint();
          final down = _pointerDown;
          if (!details.wasAccepted &&
              down != null &&
              (details.offset - down).distance < 24) {
            _showMoveDialog(token);
          }
        },
        feedback: _dragFeedback(token),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      ),
    );
  }

  void _clearDropHint() {
    if (_dropHint != null && mounted) setState(() => _dropHint = null);
  }

  Widget _buildTokenCardBody(Token token, {Widget? dragHandle}) {
    return TokenCard(
      key: ValueKey(token.id),
      token: token,
      dragHandle: dragHandle,
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
      // While searching there is no drag; long-press opens the move sheet.
      onMoveToProfile: _isSearching ? () => _showMoveDialog(token) : null,
    );
  }

  /// Puts [token] in a profile and category together. They are always set as a
  /// pair: a category belongs to one profile, so setting only one of them
  /// would leave the token filed under a category its profile doesn't have.
  Future<void> _moveToken(Token token, String? profileId, String? groupId,
      {bool refresh = true}) async {
    if (token.profileId == profileId && token.groupId == groupId) return;
    final repo = ref.read(tokenRepositoryProvider);
    await repo.updateProfile(token.id, profileId);
    await repo.updateGroup(token.id, groupId);
    if (refresh) ref.invalidate(tokenListProvider);
  }

  /// Where a token dropped on [section] goes.
  TokenDestination _destinationOf(_SectionData section) {
    final group = section.group;
    if (group != null) return (profileId: group.profileId, groupId: group.id);
    if (section.profile != null) return (profileId: section.profile!.id, groupId: null);
    if (section.sectionId == AllViewSection.generalId(null)) {
      return (profileId: null, groupId: null);
    }
    return (profileId: ref.read(activeProfileIdProvider), groupId: null);
  }

  void _showMoveDialog(Token token) async {
    // Nothing else watches every profile's groups, so they may not be loaded.
    final groups = await ref.read(allGroupsProvider.future);
    if (!mounted) return;
    final to = await pickTokenDestination(
      context,
      title: 'Move ${token.issuer.isEmpty ? token.account : token.issuer} to',
      profiles: _profiles,
      groups: groups,
      current: (profileId: token.profileId, groupId: token.groupId),
    );
    if (to == null) return;
    await _moveToken(token, to.profileId, to.groupId);
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
              child: CitadelLogo(size: 96),
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

/// One collapsible section on the Home screen: either the synthetic
/// "General" bucket (group == null) or a real TokenGroup.
class _SectionData {
  final TokenGroup? group;
  final List<Token> tokens;

  /// Set on the "All" tab, which has one General per profile and labels each
  /// section with its owner.
  final String? id;
  final Profile? profile;

  const _SectionData({
    required this.group,
    required this.tokens,
    this.id,
    this.profile,
  });

  bool get isGeneral => group == null;
  /// Stable identity for Keys/maps — independent of position.
  String get sectionId => id ?? group?.id ?? '__general__';
}
