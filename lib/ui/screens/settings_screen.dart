import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../core/crypto/import_export.dart';
import '../../core/crypto/vault_encryption.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/palette.dart';
import '../widgets/master_password_dialog.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(theme, 'Appearance'),
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel(themeMode)),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Personal Theme'),
            subtitle: Text(_accentLabel(accent)),
            trailing: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor),
              ),
            ),
            onTap: () => _showAccentPicker(context, ref),
          ),

          _sectionHeader(theme, 'Security'),
          _BiometricTile(ref: ref),
          _PinTile(ref: ref),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Auto-lock Timeout'),
            subtitle: Text(_formatDuration(ref.watch(autoLockDurationProvider))),
            onTap: () => _showAutoLockPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Lock Now'),
            onTap: () {
              ref.read(vaultProvider.notifier).lock();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),

          _sectionHeader(theme, 'Data'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import Tokens'),
            subtitle: const Text('From other authenticator apps'),
            onTap: () => _importTokens(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export Tokens'),
            subtitle: const Text('Encrypted or plaintext backup'),
            onTap: () => _showExportDialog(context, ref),
          ),

          _sectionHeader(theme, 'About'),
          ListTile(
            leading: SvgPicture.asset(
              'assets/logo/citadel_logo.svg',
              width: 24,
              height: 24,
            ),
            title: const Text('Citadel Auth'),
            subtitle: Text(
              ref.watch(appVersionProvider).maybeWhen(
                    data: (v) => 'v$v - Privacy-first 2FA',
                    orElse: () => 'Privacy-first 2FA',
                  ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Open Source'),
            subtitle: Text('Apache-2.0 License'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Commitment'),
            subtitle: Text('No telemetry. No cloud. No paywalls.'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => launchUrl(Uri.parse('https://www.energma.co/privacy-policy')),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('Terms of Use'),
            onTap: () => launchUrl(Uri.parse('https://www.energma.co/terms-of-use')),
          ),

          _sectionHeader(theme, 'Danger Zone'),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text('Delete Vault', style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text('Permanently delete all data'),
            onTap: () => _deleteVault(context, ref),
          ),
          const SizedBox(height: 24),

          // Powered by Energma
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'Powered by',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo/energma_logo.png',
                      width: 20,
                      height: 20,
                      color: Palette.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ENERGMA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          _themeOption(ctx, ref, ThemeMode.system, 'System default', Icons.brightness_auto, current),
          _themeOption(ctx, ref, ThemeMode.light, 'Light', Icons.light_mode, current),
          _themeOption(ctx, ref, ThemeMode.dark, 'Dark', Icons.dark_mode, current),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, WidgetRef ref, ThemeMode mode, String label, IconData icon, ThemeMode current) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = mode;
        final modeStr = switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        };
        ref.read(keystoreServiceProvider).storeThemeMode(modeStr);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (mode == current) const Icon(Icons.check, size: 20, color: Palette.primary),
        ],
      ),
    );
  }

  String _accentLabel(Color accent) {
    for (final (name, color) in Palette.accentPresets) {
      if (color.toARGB32() == accent.toARGB32()) return name;
    }
    return 'Custom';
  }

  void _showAccentPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _AccentPickerDialog(),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes == 0) return 'Immediately';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return '${d.inHours} hour${d.inHours > 1 ? 's' : ''}';
  }

  void _showAutoLockPicker(BuildContext context, WidgetRef ref) {
    final options = [
      (const Duration(minutes: 0), 'Immediately'),
      (const Duration(minutes: 1), '1 minute'),
      (const Duration(minutes: 5), '5 minutes'),
      (const Duration(minutes: 15), '15 minutes'),
      (const Duration(minutes: 30), '30 minutes'),
      (const Duration(hours: 1), '1 hour'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-lock Timeout'),
        children: options.map((o) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(autoLockDurationProvider.notifier).state = o.$1;
              ref.read(keystoreServiceProvider).storeAutoLockMinutes(o.$1.inMinutes);
              Navigator.pop(ctx);
            },
            child: Text(o.$2),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _importTokens(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final file = File(picked.path!);
    final rawContent = await file.readAsString();

    // Encrypted backups are stored as `base64(salt)\n<ciphertext>` and must be
    // decrypted with the export password before the token JSON can be parsed.
    String content = rawContent;
    if (_looksEncrypted(picked.name, rawContent)) {
      if (!context.mounted) return;
      final password = await _promptImportPassword(context);
      if (password == null || password.isEmpty) return;

      try {
        content = await _decryptExport(rawContent, password);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password or corrupted backup file'),
            ),
          );
        }
        return;
      }
    }

    try {
      final tokens = ImportExport.importFromJson(content);
      if (tokens.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tokens found in file')),
          );
        }
        return;
      }

      await ref.read(tokenRepositoryProvider).importTokens(tokens);
      ref.invalidate(tokenListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${tokens.length} tokens')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  /// Detects whether a picked file is a Citadel encrypted export rather than
  /// plaintext JSON / otpauth URIs. Matches on the `.enc` extension or the
  /// `base64(salt)\n<ciphertext>` shape produced by [_exportTokensEncrypted].
  bool _looksEncrypted(String fileName, String content) {
    if (fileName.toLowerCase().endsWith('.enc')) return true;

    final trimmed = content.trimLeft();
    // Plaintext exports start with a JSON object/array or an otpauth URI.
    if (trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('otpauth')) {
      return false;
    }

    final newlineIdx = content.indexOf('\n');
    if (newlineIdx <= 0) return false;
    try {
      // First line must be the base64-encoded salt (32 bytes).
      final salt = base64.decode(content.substring(0, newlineIdx).trim());
      return salt.length == 32;
    } catch (_) {
      return false;
    }
  }

  /// Reverses [_exportTokensEncrypted]: parses the salt, derives the key from
  /// [password], and returns the decrypted token JSON. Throws if the password
  /// is wrong or the file is corrupted.
  Future<String> _decryptExport(String content, String password) async {
    final newlineIdx = content.indexOf('\n');
    if (newlineIdx <= 0) {
      throw const FormatException('Malformed encrypted backup');
    }
    final salt = base64.decode(content.substring(0, newlineIdx).trim());
    final ciphertext = content.substring(newlineIdx + 1).trim();
    final key = await VaultEncryption.deriveKey(password, salt);
    return VaultEncryption.decryptString(ciphertext, key);
  }

  /// Prompts for the password used to encrypt an imported backup file.
  Future<String?> _promptImportPassword(BuildContext context) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encrypted Backup'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
          decoration: InputDecoration(
            labelText: 'Export Password',
            hintText: 'Password used to encrypt this file',
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withAlpha(100),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withAlpha(80),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Tokens'),
        content: const Text('Choose export format. Plaintext exports contain your secret keys in readable form.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportTokens(context, ref, encrypted: false);
            },
            child: const Text('Plaintext (JSON)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showEncryptedExportDialog(context, ref);
            },
            child: const Text('Encrypted'),
          ),
        ],
      ),
    );
  }

  /// Readable, sortable backup name — the date and token count tell the user
  /// which backup is which long after the export (epoch stamps didn't).
  String _exportFileName(int tokenCount, String extension) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    return 'citadel-backup-$stamp-$tokenCount-tokens.$extension';
  }

  Future<void> _exportTokens(BuildContext context, WidgetRef ref, {required bool encrypted}) async {
    final tokens = await ref.read(tokenRepositoryProvider).getAll();
    if (tokens.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tokens to export')),
        );
      }
      return;
    }

    final json = ImportExport.exportToJson(tokens);

    // Save the backup to a location the user picks on this device. We
    // deliberately use the file-save picker rather than the OS share sheet so
    // secrets never leave the phone via email/WhatsApp/Viber/etc.
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup to this device',
      fileName: _exportFileName(tokens.length, 'json'),
      bytes: utf8.encode(json),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null ? 'Export cancelled' : 'Backup saved to device'),
        ),
      );
    }
  }

  void _showEncryptedExportDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encrypted Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a password to protect the export file.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Export Password',
                hintText: 'Create a password',
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(100),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(80),
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
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter the password',
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(100),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(80),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.isEmpty) return;
              if (password != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _exportTokensEncrypted(context, ref, password);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTokensEncrypted(BuildContext context, WidgetRef ref, String password) async {
    final tokens = await ref.read(tokenRepositoryProvider).getAll();
    if (tokens.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tokens to export')),
        );
      }
      return;
    }

    final json = ImportExport.exportToJson(tokens);
    final salt = VaultEncryption.generateSalt();
    final key = await VaultEncryption.deriveKey(password, salt);
    final encrypted = await VaultEncryption.encryptString(json, key);

    // Format: base64(salt) + '\n' + encrypted
    final exportContent = '${base64.encode(salt)}\n$encrypted';

    // Save on-device only — no share sheet, so the encrypted backup can't be
    // routed off the phone through messaging apps.
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted backup to this device',
      fileName: _exportFileName(tokens.length, 'citadel.enc'),
      bytes: utf8.encode(exportContent),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null ? 'Export cancelled' : 'Encrypted backup saved to device'),
        ),
      );
    }
  }

  void _deleteVault(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vault'),
        content: const Text(
          'This will permanently delete ALL your tokens and data. '
          'This action cannot be undone. Make sure you have exported a backup.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Wiping the vault is the most destructive action — require the master
      // password before erasing everything.
      showDialog(
        context: context,
        builder: (pwdCtx) => MasterPasswordDialog(
          title: 'Confirm Vault Deletion',
          subtitle:
              'Enter your master password to permanently delete all data.',
          onConfirm: () async {
            final db = ref.read(vaultDatabaseProvider);
            await db.deleteVault();
            final keystore = ref.read(keystoreServiceProvider);
            await keystore.clearAll();
            ref.read(vaultProvider.notifier).checkStatus();
            if (context.mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
        ),
      );
    }
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _BiometricTile({required this.ref});

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final biometricAsync = ref.watch(biometricEnabledProvider);

    return ListTile(
      leading: const Icon(Icons.fingerprint),
      title: const Text('Biometric Unlock'),
      subtitle: const Text('Use fingerprint or face to unlock'),
      trailing: biometricAsync.when(
        data: (enabled) => Switch(
          value: enabled,
          onChanged: _toggling ? null : (v) => _toggle(v),
        ),
        loading: () => const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, _) => const Switch(value: false, onChanged: null),
      ),
    );
  }

  Future<void> _toggle(bool value) async {
    setState(() => _toggling = true);
    try {
      final keystore = ref.read(keystoreServiceProvider);
      if (value) {
        final bio = ref.read(biometricServiceProvider);
        final available = await bio.isAvailable();
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometrics not available on this device')),
            );
          }
          setState(() => _toggling = false);
          return;
        }
      }
      await keystore.setBiometricEnabled(value);
      ref.invalidate(biometricEnabledProvider);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }
}

class _PinTile extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PinTile({required this.ref});

  @override
  ConsumerState<_PinTile> createState() => _PinTileState();
}

class _PinTileState extends ConsumerState<_PinTile> {
  @override
  Widget build(BuildContext context) {
    final pinAsync = ref.watch(pinEnabledProvider);

    return pinAsync.when(
      data: (enabled) => ListTile(
        leading: const Icon(Icons.pin_rounded),
        title: Text(enabled ? 'Change or Remove PIN' : 'Set Up PIN'),
        subtitle: Text(enabled ? 'PIN is active' : 'Add a PIN as extra security factor'),
        onTap: () => enabled ? _showPinOptions(context) : _setupPin(context),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.pin_rounded),
        title: Text('PIN'),
        trailing: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showPinOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('PIN Settings'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _changePin(context);
            },
            child: const Text('Change PIN'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _removePin(context);
            },
            child: const Text('Remove PIN', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _setupPin(BuildContext context) async {
    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin == null || !mounted) return;

    final keystore = ref.read(keystoreServiceProvider);
    final db = ref.read(vaultDatabaseProvider);

    // Re-key database: current passphrase + new PIN
    // We need the current passphrase — prompt user
    final password = await _promptPassword(context, 'Enter your master password to enable PIN');
    if (password == null || !mounted) return;

    if (!await keystore.verifyMasterPassword(password)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect master password')),
        );
      }
      return;
    }

    try {
      final newPassphrase = '$password$pin';
      await db.rekey(newPassphrase);

      // Store master password for PIN-only login
      await keystore.storeMasterPassword(password);

      // The PIN is part of the passphrase; just record that PIN unlock is on.
      await keystore.setPinEnabled(true);

      // Update stored vault key for biometric
      final bioEnabled = await keystore.isBiometricEnabled();
      if (bioEnabled) {
        await keystore.storeVaultKey(utf8.encode(newPassphrase));
      }

      ref.invalidate(pinEnabledProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN enabled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable PIN: $e')),
        );
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final newPin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen(title: 'Change PIN')),
    );
    if (newPin == null || !mounted) return;

    final password = await _promptPassword(context, 'Enter your master password');
    if (password == null || !mounted) return;

    final keystore = ref.read(keystoreServiceProvider);
    final db = ref.read(vaultDatabaseProvider);

    if (!await keystore.verifyMasterPassword(password)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect master password')),
        );
      }
      return;
    }

    try {
      final newPassphrase = '$password$newPin';
      await db.rekey(newPassphrase);

      // Store master password for PIN-only login
      await keystore.storeMasterPassword(password);

      await keystore.setPinEnabled(true);

      final bioEnabled = await keystore.isBiometricEnabled();
      if (bioEnabled) {
        await keystore.storeVaultKey(utf8.encode(newPassphrase));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change PIN: $e')),
        );
      }
    }
  }

  Future<void> _removePin(BuildContext context) async {
    final password = await _promptPassword(context, 'Enter your master password to remove PIN');
    if (password == null || !mounted) return;

    final keystore = ref.read(keystoreServiceProvider);
    final db = ref.read(vaultDatabaseProvider);

    if (!await keystore.verifyMasterPassword(password)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect master password')),
        );
      }
      return;
    }

    try {
      await db.rekey(password);

      // Store master password for PIN-only login (even when PIN is removed)
      await keystore.storeMasterPassword(password);

      await keystore.clearPin();

      final bioEnabled = await keystore.isBiometricEnabled();
      if (bioEnabled) {
        await keystore.storeVaultKey(utf8.encode(password));
      }

      ref.invalidate(pinEnabledProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove PIN: $e')),
        );
      }
    }
  }

  Future<String?> _promptPassword(BuildContext context, String title) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Master Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withAlpha(100),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withAlpha(80),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Accent picker for the Personal Theme setting. Changes apply live — the whole
/// app re-themes as you drag — so there is no separate preview to keep in sync.
class _AccentPickerDialog extends ConsumerStatefulWidget {
  const _AccentPickerDialog();

  @override
  ConsumerState<_AccentPickerDialog> createState() =>
      _AccentPickerDialogState();
}

class _AccentPickerDialogState extends ConsumerState<_AccentPickerDialog> {
  void _apply(Color color) {
    ref.read(accentColorProvider.notifier).state = color;
    ref.read(keystoreServiceProvider).storeAccentColor(color.toARGB32());
  }

  void _reset() {
    ref.read(accentColorProvider.notifier).state = Palette.primary;
    ref.read(keystoreServiceProvider).clearAccentColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ref.watch(accentColorProvider);
    final hue = HSLColor.fromColor(selected).hue;

    return AlertDialog(
      title: const Text('Personal Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent color', style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (name, color) in Palette.accentPresets)
                _swatch(color, name, selected),
            ],
          ),
          const SizedBox(height: 20),
          Text('Custom hue', style: theme.textTheme.labelMedium),
          Slider(
            value: hue,
            max: 360,
            onChanged: (h) =>
                _apply(HSLColor.fromAHSL(1, h, 0.72, 0.52).toColor()),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Token'),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
              ),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: () {}, child: const Text('Preview')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _reset, child: const Text('Reset')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _swatch(Color color, String name, Color selected) {
    final isSelected = color.toARGB32() == selected.toARGB32();
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: () => _apply(color),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check, size: 20, color: AppTheme.onAccent(color))
              : null,
        ),
      ),
    );
  }
}
