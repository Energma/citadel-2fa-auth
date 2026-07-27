import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/otp_engine.dart';
import '../../core/models/token.dart';
import '../../core/providers.dart';
import '../widgets/qr_scanner.dart';

class AddTokenScreen extends ConsumerStatefulWidget {
  final Token? editToken;

  const AddTokenScreen({super.key, this.editToken});

  @override
  ConsumerState<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends ConsumerState<AddTokenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _issuerController = TextEditingController();
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  final _uriController = TextEditingController();

  OtpType _type = OtpType.totp;
  Algorithm _algorithm = Algorithm.sha1;
  int _digits = 6;
  int _period = 30;
  String? _profileId;
  String? _groupId;
  String? _error;
  bool _secretRevealed = false;

  bool get _isEditing => widget.editToken != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 1 : 3, vsync: this);
    if (_isEditing) {
      final t = widget.editToken!;
      _issuerController.text = t.issuer;
      _accountController.text = t.account;
      _secretController.text = t.secret;
      _type = t.type;
      _algorithm = t.algorithm;
      _digits = t.digits;
      _period = t.period;
      _profileId = t.profileId;
      _groupId = t.groupId;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _issuerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    _uriController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    final issuer = _issuerController.text.trim();
    final account = _accountController.text.trim();

    if (account.isEmpty) {
      setState(() => _error = 'Account name is required');
      return;
    }

    final repo = ref.read(tokenRepositoryProvider);

    if (_isEditing) {
      // The secret and OTP parameters define code generation and are fixed
      // by the service at enrollment — only labels and organization change.
      // Built directly (not via copyWith) so profile/group can be cleared.
      final t = widget.editToken!;
      final updated = Token(
        id: t.id,
        issuer: issuer,
        account: account,
        secret: t.secret,
        type: t.type,
        algorithm: t.algorithm,
        digits: t.digits,
        period: t.period,
        counter: t.counter,
        iconPath: t.iconPath,
        profileId: _profileId,
        groupId: _groupId,
        tags: t.tags,
        isPinned: t.isPinned,
        sortOrder: t.sortOrder,
        createdAt: t.createdAt,
      );
      await repo.update(updated);
    } else {
      final secret = _secretController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[\s\-]'), '');

      if (secret.isEmpty) {
        setState(() => _error = 'Secret key is required');
        return;
      }
      if (!OtpEngine.isValidSecret(secret)) {
        setState(() => _error = 'Invalid Base32 secret key');
        return;
      }

      final token = Token(
        issuer: issuer,
        account: account,
        secret: secret,
        type: _type,
        algorithm: _algorithm,
        digits: _digits,
        period: _period,
        profileId: _profileId,
        groupId: _groupId,
      );
      await repo.add(token);
    }

    if (mounted) Navigator.pop(context);
  }

  void _handleQrScanned(String code) {
    try {
      if (code.startsWith('otpauth://')) {
        final token = Token.fromUri(code);
        _issuerController.text = token.issuer;
        _accountController.text = token.account;
        _secretController.text = token.secret;
        setState(() {
          _type = token.type;
          _algorithm = token.algorithm;
          _digits = token.digits;
          _period = token.period;
          _error = null;
        });
        _tabController
            .animateTo(_tabController.length - 1); // Go to manual tab
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code scanned successfully')),
        );
      } else {
        setState(() => _error = 'Not a valid otpauth:// QR code');
      }
    } catch (e) {
      setState(() => _error = 'Failed to parse QR code: $e');
    }
  }

  void _handleUriPaste() {
    final uri = _uriController.text.trim();
    if (uri.isEmpty) return;
    _handleQrScanned(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Token' : 'Add Token'),
        bottom: _isEditing
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
                  Tab(icon: Icon(Icons.link), text: 'Paste URI'),
                  Tab(icon: Icon(Icons.edit), text: 'Manual'),
                ],
              ),
      ),
      body: _isEditing
          ? _buildManualForm(theme)
          : TabBarView(
              controller: _tabController,
              children: [
                // QR Scanner tab
                ClipRect(
                    child:
                        QrScannerWidget(onScanned: _handleQrScanned)),
                // URI paste tab
                ClipRect(
                    child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paste otpauth:// URI',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _uriController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'otpauth:// URI',
                          hintText:
                              'otpauth://totp/Example:user@email.com?secret=...',
                          prefixIcon: const Icon(Icons.link),
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
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleUriPaste,
                          child: const Text('Parse URI'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: theme.colorScheme.error)),
                      ],
                    ],
                  ),
                )),
                // Manual entry tab
                ClipRect(child: _buildManualForm(theme)),
              ],
            ),
    );
  }

  Widget _buildManualForm(ThemeData theme) {
    final profiles = ref.watch(profileListProvider);
    final groups = ref.watch(groupListProvider);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      // Bottom padding leaves room for the system nav bar so the CTA button
      // at the end of the form isn't hidden behind it once Advanced options
      // push the content past the viewport height.
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _issuerController,
            decoration: InputDecoration(
              labelText: 'Service / Issuer',
              hintText: 'e.g. GitHub, Google, AWS',
              prefixIcon: const Icon(Icons.business),
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountController,
            decoration: InputDecoration(
              labelText: 'Account *',
              hintText: 'e.g. user@email.com',
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secretController,
            readOnly: _isEditing,
            obscureText: _isEditing && !_secretRevealed,
            // Reveal is for visual verification only — without this, a
            // revealed read-only field still offers Select All/Copy, putting
            // the raw seed on the system clipboard.
            enableInteractiveSelection: !_isEditing,
            decoration: InputDecoration(
              labelText: _isEditing
                  ? 'Secret Key (cannot be changed)'
                  : 'Secret Key (Base32) *',
              hintText: 'e.g. JBSWY3DPEHPK3PXP',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: _isEditing
                  ? IconButton(
                      icon: Icon(_secretRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      tooltip:
                          _secretRevealed ? 'Hide secret' : 'Reveal secret',
                      onPressed: () => setState(
                          () => _secretRevealed = !_secretRevealed),
                    )
                  : null,
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
          ),
          const SizedBox(height: 16),

          // Profile selector
          profiles.when(
            data: (profileList) {
              final selected =
                  profileList.where((p) => p.id == _profileId).firstOrNull;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showOptionPicker<String?>(
                  title: 'Profile',
                  options: [null, ...profileList.map((p) => p.id)],
                  current: _profileId,
                  labelOf: (id) => id == null
                      ? 'None'
                      : profileList.firstWhere((p) => p.id == id).name,
                  leadingOf: (id) => id == null
                      ? null
                      : CircleAvatar(
                          backgroundColor:
                              profileList.firstWhere((p) => p.id == id).color,
                          radius: 6),
                  onSelected: (v) => setState(() => _profileId = v),
                ),
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
                      if (selected != null) ...[
                        CircleAvatar(
                            backgroundColor: selected.color, radius: 6),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(selected?.name ?? 'None',
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: theme.colorScheme.onSurface.withAlpha(140)),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // Group selector
          groups.when(
            data: (groupList) {
              if (groupList.isEmpty) return const SizedBox.shrink();
              final selected =
                  groupList.where((g) => g.id == _groupId).firstOrNull;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showOptionPicker<String?>(
                  title: 'Group',
                  options: [null, ...groupList.map((g) => g.id)],
                  current: _groupId,
                  labelOf: (id) => id == null
                      ? 'None'
                      : groupList.firstWhere((g) => g.id == id).name,
                  leadingOf: (id) => id == null
                      ? null
                      : Icon(Icons.folder_rounded,
                          color: theme.colorScheme.primary),
                  onSelected: (v) => setState(() => _groupId = v),
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Group',
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
                      if (selected != null) ...[
                        Icon(Icons.folder_rounded,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(selected?.name ?? 'None',
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: theme.colorScheme.onSurface.withAlpha(140)),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          // Advanced settings
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(6)
                  : Colors.black.withAlpha(6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withAlpha(140)),
                    const SizedBox(width: 10),
                    Text(
                      'Advanced',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            theme.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
                children: [
                  const SizedBox(height: 8),
                  _buildAdvancedRow(
                    theme,
                    left: _buildAdvancedChip(
                      theme: theme,
                      label: 'Type',
                      value: _type.name.toUpperCase(),
                      icon: Icons.code_rounded,
                      onTap: _isEditing
                          ? null
                          : () => _showOptionPicker<OtpType>(
                                title: 'OTP Type',
                                options: OtpType.values,
                                current: _type,
                                labelOf: (v) => v.name.toUpperCase(),
                                onSelected: (v) =>
                                    setState(() => _type = v),
                              ),
                    ),
                    right: _buildAdvancedChip(
                      theme: theme,
                      label: 'Algorithm',
                      value: _algorithm.name.toUpperCase(),
                      icon: Icons.lock_rounded,
                      onTap: _isEditing
                          ? null
                          : () => _showOptionPicker<Algorithm>(
                                title: 'Algorithm',
                                options: Algorithm.values,
                                current: _algorithm,
                                labelOf: (v) => v.name.toUpperCase(),
                                onSelected: (v) =>
                                    setState(() => _algorithm = v),
                              ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAdvancedRow(
                    theme,
                    left: _buildAdvancedChip(
                      theme: theme,
                      label: 'Digits',
                      value: '$_digits',
                      icon: Icons.pin_rounded,
                      onTap: _isEditing
                          ? null
                          : () => _showOptionPicker<int>(
                                title: 'Digits',
                                options: [6, 7, 8],
                                current: _digits,
                                labelOf: (v) => '$v digits',
                                onSelected: (v) =>
                                    setState(() => _digits = v),
                              ),
                    ),
                    right: _buildAdvancedChip(
                      theme: theme,
                      label: 'Period',
                      value: '${_period}s',
                      icon: Icons.timer_rounded,
                      onTap: _isEditing
                          ? null
                          : () => _showOptionPicker<int>(
                                title: 'Period',
                                options: [30, 60, 90],
                                current: _period,
                                labelOf: (v) => '${v}s',
                                onSelected: (v) =>
                                    setState(() => _period = v),
                              ),
                    ),
                  ),
                  // Changing Type/Algorithm here only changes what this app
                  // expects — it can't reconfigure the issuing service, so a
                  // mismatch here means generated codes will never validate.
                  if (_type != OtpType.totp || _algorithm != Algorithm.sha1) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withAlpha(140)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Type and Algorithm must exactly match what your '
                            'provider issued — most services use TOTP + SHA1. '
                            "Changing these here won't reconfigure the provider.",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveToken,
              child: Text(_isEditing ? 'Save Changes' : 'Add Token'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedRow(ThemeData theme,
      {required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildAdvancedChip({
    required ThemeData theme,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(8)
              : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.black.withAlpha(8),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: theme.colorScheme.primary.withAlpha(180)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withAlpha(100),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(60)),
          ],
        ),
      ),
    );
  }

  void _showOptionPicker<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) labelOf,
    required void Function(T) onSelected,
    Widget? Function(T)? leadingOf,
  }) {
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
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                ...options.map((opt) => ListTile(
                      leading: leadingOf?.call(opt),
                      title: Text(labelOf(opt)),
                      trailing: opt == current
                          ? Icon(Icons.check_rounded,
                              color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        onSelected(opt);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
