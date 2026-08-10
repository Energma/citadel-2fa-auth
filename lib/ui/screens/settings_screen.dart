import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/models/theme_settings.dart';
import '../../core/providers.dart';
import '../../core/crypto/import_export.dart';
import '../../core/crypto/vault_encryption.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/palette.dart';
import '../widgets/master_password_dialog.dart';
import 'pin_setup_screen.dart';
import 'vault_deleted_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final citadelThemeMode = ref.watch(citadelThemeModeProvider);
    final customColors = ref.watch(customThemeColorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(theme, 'Appearance'),
          ListTile(
            leading: Icon(switch (citadelThemeMode) {
              CitadelThemeMode.custom => Icons.palette,
              _ => isDark ? Icons.dark_mode : Icons.light_mode,
            }),
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel(citadelThemeMode)),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Personal Theme'),
            subtitle: const Text('Background, text and element colors for Custom theme'),
            trailing: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: customColors.element,
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor),
              ),
            ),
            onTap: () => _showCustomThemeDialog(context, ref),
          ),

          _sectionHeader(theme, 'Security'),
          _BiometricTile(ref: ref),
          _DeviceCredentialTile(ref: ref),
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
            leading: Image.asset(
              'assets/logo/citadel-logo.png',
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
                      color: theme.colorScheme.onSurface,
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

  String _themeModeLabel(CitadelThemeMode mode) {
    return switch (mode) {
      CitadelThemeMode.system => 'System default',
      CitadelThemeMode.light => 'Light',
      CitadelThemeMode.dark => 'Dark',
      CitadelThemeMode.custom => 'Custom',
    };
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(citadelThemeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          _themeOption(ctx, ref, CitadelThemeMode.system, 'System default', Icons.brightness_auto, current),
          _themeOption(ctx, ref, CitadelThemeMode.light, 'Light', Icons.light_mode, current),
          _themeOption(ctx, ref, CitadelThemeMode.dark, 'Dark', Icons.dark_mode, current),
          _themeOption(ctx, ref, CitadelThemeMode.custom, 'Custom', Icons.palette, current),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, WidgetRef ref, CitadelThemeMode mode, String label, IconData icon, CitadelThemeMode current) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(citadelThemeModeProvider.notifier).state = mode;
        final modeStr = switch (mode) {
          CitadelThemeMode.light => 'light',
          CitadelThemeMode.dark => 'dark',
          CitadelThemeMode.custom => 'custom',
          CitadelThemeMode.system => 'system',
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

  void _showCustomThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _CustomThemeDialog(),
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
            child: Text('Delete Everything', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Set inside onConfirm only once deletion actually succeeds, so a
    // cancelled or failed confirmation never triggers the screen below.
    var deleted = false;

    // Wiping the vault is the most destructive action — require the master
    // password before erasing everything.
    await showDialog(
      context: context,
      builder: (pwdCtx) => MasterPasswordDialog(
        title: 'Confirm Vault Deletion',
        subtitle: 'Enter your master password to permanently delete all data.',
        onConfirm: () async {
          final db = ref.read(vaultDatabaseProvider);
          await db.deleteVault();
          final keystore = ref.read(keystoreServiceProvider);
          await keystore.clearAll();
          // keystore.clearAll() wipes every persisted setting, but the
          // Riverpod providers caching them in memory don't know that on
          // their own — without invalidating them here, a vault created
          // right after deletion would keep showing the previous vault's
          // PIN/biometric/theme/custom-colors/auto-lock state until the app is
          // killed and restarted. Invalidating a StateProvider re-runs its
          // initial `(ref) => ...` callback, which resets it to the same
          // default it would have on a fresh install.
          ref.invalidate(pinEnabledProvider);
          ref.invalidate(biometricEnabledProvider);
          ref.invalidate(autoLockDurationProvider);
          ref.invalidate(citadelThemeModeProvider);
          ref.invalidate(customThemeColorsProvider);
          ref.invalidate(allViewGeneralSortOrderProvider);
          deleted = true;
        },
      ),
    );

    if (deleted && context.mounted) {
      // The vault state only flips to uninitialized once this screen's
      // message+logo sequence finishes — see VaultDeletedScreen.onComplete.
      // Without it, popping straight back here would reveal a stale
      // HomeScreen pointed at the just-deleted database for a frame.
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VaultDeletedScreen(
            onComplete: () => ref.read(vaultProvider.notifier).checkStatus(),
          ),
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
      trailing: _toggling
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : biometricAsync.when(
              data: (enabled) => Switch(
                value: enabled,
                onChanged: (v) => _toggle(v),
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
    final keystore = ref.read(keystoreServiceProvider);

    try {
      final pinEnabled = await ref.read(pinEnabledProvider.future);

      if (!value) {
        await keystore.setBiometricEnabled(false);
        // Biometric is layered on top of whatever the primary method is —
        // an app PIN if one exists, otherwise the master password.
        await keystore.setUnlockMethod(pinEnabled ? 'pin' : 'password');
        // Drop the stored vault key too — otherwise the lock screen keeps
        // offering a "Use device screen lock" fallback for a method the
        // user just explicitly turned off.
        await keystore.clearVaultKey();
        ref.invalidate(biometricEnabledProvider);
        return;
      }

      final bio = ref.read(biometricServiceProvider);
      // This toggle means a real fingerprint/face scan — requires actual
      // sensor hardware with something enrolled, regardless of whether a PIN
      // is set. A device with only a PIN/pattern screen lock and no sensor
      // is covered by the separate "Device Unlock" toggle instead, so the
      // lock screen never flashes a fingerprint prompt that can never
      // succeed.
      if (!await bio.hasBiometricHardware()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }
      if (!mounted) return;

      // Turning biometric unlock on has to (re)store the exact passphrase
      // the vault is encrypted with, so the lock screen can hand it back
      // after a successful scan. Re-verifying the master password here
      // isn't just identity confirmation — it's the passphrase material
      // itself for accounts with no PIN.
      final password = await _promptPassword(
          context, 'Enter your master password to set up biometric unlock');
      if (password == null || !mounted) return;

      if (!await keystore.verifyMasterPassword(password)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect master password')),
          );
        }
        return;
      }

      String passphrase;
      if (pinEnabled) {
        // The PIN is mixed into the passphrase but never stored on its own
        // (see KeystoreService.setPinEnabled) — it has to be re-entered here
        // to rebuild the exact passphrase the vault is encrypted with.
        final db = ref.read(vaultDatabaseProvider);
        final pin = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => PinConfirmScreen(
              subtitle: 'Enter your app PIN to set up biometric unlock.',
              verify: (candidate) =>
                  db.verifyPassphrase('$password$candidate'),
            ),
          ),
        );
        if (pin == null || !mounted) return;
        passphrase = '$password$pin';
      } else {
        passphrase = password;
      }

      await keystore.storeMasterPassword(password);
      await keystore.storeVaultKey(utf8.encode(passphrase));
      await keystore.setBiometricEnabled(true);
      await keystore.setUnlockMethod('biometric');
      ref.invalidate(biometricEnabledProvider);
      ref.invalidate(deviceCredentialEnabledProvider);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }
}

class _DeviceCredentialTile extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _DeviceCredentialTile({required this.ref});

  @override
  ConsumerState<_DeviceCredentialTile> createState() =>
      _DeviceCredentialTileState();
}

class _DeviceCredentialTileState extends ConsumerState<_DeviceCredentialTile> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final deviceCredentialAsync = ref.watch(deviceCredentialEnabledProvider);

    return ListTile(
      leading: const Icon(Icons.phonelink_lock_outlined),
      title: const Text('Device Unlock'),
      subtitle: const Text(
          "Unlock with your phone's PIN, pattern, password, or biometrics"),
      trailing: _toggling
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : deviceCredentialAsync.when(
              data: (enabled) => Switch(
                value: enabled,
                onChanged: (v) => _toggle(v),
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
    final keystore = ref.read(keystoreServiceProvider);

    try {
      final pinEnabled = await ref.read(pinEnabledProvider.future);

      if (!value) {
        // Device-credential unlock is layered on top of whatever the
        // primary method is — an app PIN if one exists, otherwise the
        // master password. Distinct from (and independent of) the
        // Biometric Unlock toggle above.
        await keystore.setUnlockMethod(pinEnabled ? 'pin' : 'password');
        // Drop the stored vault key too — otherwise the lock screen keeps
        // offering a "Use device screen lock" fallback even though the
        // user just explicitly turned this off; from here on in, only the
        // master password (or PIN) should get them in.
        await keystore.clearVaultKey();
        ref.invalidate(deviceCredentialEnabledProvider);
        return;
      }

      final bio = ref.read(biometricServiceProvider);
      // Unlike Biometric Unlock, this only needs *some* secure screen lock —
      // PIN, pattern, password, or biometric — not real sensor hardware.
      if (!await bio.isAvailable()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No screen lock found on this phone')),
          );
        }
        return;
      }
      if (!mounted) return;

      // Turning device unlock on has to (re)store the exact passphrase the
      // vault is encrypted with, so the lock screen can hand it back after a
      // successful device-credential prompt.
      final password = await _promptPassword(
          context, 'Enter your master password to set up device unlock');
      if (password == null || !mounted) return;

      if (!await keystore.verifyMasterPassword(password)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect master password')),
          );
        }
        return;
      }

      String passphrase;
      if (pinEnabled) {
        final db = ref.read(vaultDatabaseProvider);
        final pin = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => PinConfirmScreen(
              subtitle: 'Enter your app PIN to set up device unlock.',
              verify: (candidate) =>
                  db.verifyPassphrase('$password$candidate'),
            ),
          ),
        );
        if (pin == null || !mounted) return;
        passphrase = '$password$pin';
      } else {
        passphrase = password;
      }

      await keystore.storeMasterPassword(password);
      await keystore.storeVaultKey(utf8.encode(passphrase));
      await keystore.setUnlockMethod('deviceCredential');
      ref.invalidate(deviceCredentialEnabledProvider);
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
            child: Text('Remove PIN', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _setupPin(BuildContext context) async {
    final keystore = ref.read(keystoreServiceProvider);
    final db = ref.read(vaultDatabaseProvider);

    // Verify the current passphrase before asking the user to go through PIN
    // entry, so a wrong password is reported immediately instead of after.
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

    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin == null || !mounted) return;

    try {
      final newPassphrase = '$password$pin';
      await db.rekey(newPassphrase);

      // Store master password for PIN-only login
      await keystore.storeMasterPassword(password);

      // The PIN is part of the passphrase; just record that PIN unlock is on.
      await keystore.setPinEnabled(true);
      // Setting up a PIN makes it the primary unlock method, overriding
      // whatever this user had before (e.g. a leftover device-lock setup) —
      // they can still layer real biometric back on via the Settings toggle.
      await keystore.setUnlockMethod('pin');

      // Update the stored vault key so an already-configured biometric or
      // device-credential unlock keeps working with the new PIN-inclusive
      // passphrase, instead of quietly going stale.
      if (await keystore.getVaultKey() != null) {
        await keystore.storeVaultKey(utf8.encode(newPassphrase));
      }

      ref.invalidate(pinEnabledProvider);
      ref.invalidate(biometricEnabledProvider);
      ref.invalidate(deviceCredentialEnabledProvider);

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
    final keystore = ref.read(keystoreServiceProvider);
    final db = ref.read(vaultDatabaseProvider);

    final password = await _promptPassword(context, 'Enter your master password');
    if (password == null || !mounted) return;

    if (!await keystore.verifyMasterPassword(password)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect master password')),
        );
      }
      return;
    }

    final newPin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen(title: 'Change PIN')),
    );
    if (newPin == null || !mounted) return;

    try {
      final newPassphrase = '$password$newPin';
      await db.rekey(newPassphrase);

      // Store master password for PIN-only login
      await keystore.storeMasterPassword(password);

      await keystore.setPinEnabled(true);

      // Same reasoning as _setupPin: keep an already-configured biometric or
      // device-credential unlock working with the new passphrase.
      if (await keystore.getVaultKey() != null) {
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

      // 'biometric' and 'deviceCredential' are both PIN add-ons — without a
      // PIN neither is a supported state, so fall back to the master
      // password and drop the now-orphaned biometric flag rather than
      // leaving a stale toggle. The stored vault key goes too: it was
      // derived from the old password+PIN passphrase, which the rekey above
      // just invalidated, so keeping it around would only offer a "Use
      // device screen lock" fallback that's guaranteed to fail.
      final method = await keystore.getUnlockMethod();
      if (method == 'biometric' || method == 'deviceCredential') {
        await keystore.setBiometricEnabled(false);
        await keystore.clearVaultKey();
      }
      await keystore.setUnlockMethod('password');

      ref.invalidate(pinEnabledProvider);
      ref.invalidate(biometricEnabledProvider);
      ref.invalidate(deviceCredentialEnabledProvider);

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
}

/// Shared master-password re-entry prompt. Used everywhere a PIN or
/// biometric flow needs to re-verify identity before touching the vault's
/// encryption passphrase — `SettingsScreen`'s PIN flows and `_BiometricTile`
/// alike, so it lives at the top level rather than on either class.
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

/// Color picker for the Custom theme's background/text/element colors.
/// Changes apply live and switch Theme to Custom immediately — the whole app
/// re-themes as you drag — so there is no separate preview to keep in sync.
class _CustomThemeDialog extends ConsumerStatefulWidget {
  const _CustomThemeDialog();

  @override
  ConsumerState<_CustomThemeDialog> createState() =>
      _CustomThemeDialogState();
}

class _CustomThemeDialogState extends ConsumerState<_CustomThemeDialog> {
  // A hue slider alone can't reach black/white/gray (it always keeps fixed
  // saturation/lightness), so Background/Text get grayscale presets instead
  // of the brand hues in [Palette.accentPresets].
  static const List<(String, Color)> _grayscalePresets = [
    ('Black', Colors.black),
    ('White', Colors.white),
    ('Slate', Color(0xFF64748B)),
  ];

  /// Applies [colors], unless it would make background and text identical
  /// (making text invisible) — that update is silently dropped instead.
  void _apply(CustomThemeColors colors) {
    if (colors.background.toARGB32() == colors.text.toARGB32()) return;
    ref.read(citadelThemeModeProvider.notifier).state = CitadelThemeMode.custom;
    ref.read(customThemeColorsProvider.notifier).state = colors;
    final keystore = ref.read(keystoreServiceProvider);
    keystore.storeThemeMode('custom');
    keystore.storeCustomBackgroundColor(colors.background.toARGB32());
    keystore.storeCustomTextColor(colors.text.toARGB32());
    keystore.storeCustomElementColor(colors.element.toARGB32());
  }

  void _reset() {
    ref.read(citadelThemeModeProvider.notifier).state = CitadelThemeMode.system;
    ref.read(customThemeColorsProvider.notifier).state = CustomThemeColors.defaults;
    final keystore = ref.read(keystoreServiceProvider);
    keystore.storeThemeMode('system');
    keystore.clearCustomBackgroundColor();
    keystore.clearCustomTextColor();
    keystore.clearCustomElementColor();
  }

  Future<void> _openFullPicker(
    BuildContext context,
    Color current,
    ValueChanged<Color> onChanged,
  ) async {
    var picked = current;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onChanged(picked);
              Navigator.pop(ctx);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ref.watch(customThemeColorsProvider);
    // The dialog's own active theme (not the device's raw OS brightness) —
    // matters when Theme is explicitly Light/Dark rather than System, where
    // the two can disagree.
    final isDarkTheme = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Personal Theme'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changing a color switches Theme to Custom.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            _colorRow(
              label: 'Background',
              selected: colors.background,
              presets: _grayscalePresets,
              onChanged: (c) => _apply(colors.copyWith(background: c)),
              blockedColor: colors.text,
              revertColor: isDarkTheme ? Colors.black : Colors.white,
              fixedSliderColor: isDarkTheme ? Colors.white : Colors.black,
            ),
            const SizedBox(height: 20),
            _colorRow(
              label: 'Text',
              selected: colors.text,
              presets: _grayscalePresets,
              onChanged: (c) => _apply(colors.copyWith(text: c)),
              blockedColor: colors.background,
              revertColor: isDarkTheme ? Colors.white : Colors.black,
              fixedSliderColor: isDarkTheme ? Colors.white : Colors.black,
            ),
            const SizedBox(height: 20),
            _colorRow(
              label: 'Element',
              selected: colors.element,
              presets: Palette.accentPresets,
              onChanged: (c) => _apply(colors.copyWith(element: c)),
            ),
          ],
        ),
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

  Widget _colorRow({
    required String label,
    required Color selected,
    required List<(String, Color)> presets,
    required ValueChanged<Color> onChanged,
    // When set, a preset matching this color is disabled — used to stop
    // Background and Text from ever being set to the same color, which
    // would make the text invisible.
    Color? blockedColor,
    // When set, shows a tappable revert icon next to the slider that jumps
    // the field straight back to this color — the hue slider itself can't
    // reach true black/white since it holds saturation/lightness fixed.
    Color? revertColor,
    // Background/Text sliders always render in the device theme's own
    // black/white (not whatever hue they're currently dragged to) — only
    // the Element slider tracks its own selected color.
    Color? fixedSliderColor,
  }) {
    final theme = Theme.of(context);
    final hue = HSLColor.fromColor(selected).hue;
    final isBlocked = blockedColor != null && blockedColor.toARGB32() == selected.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const Spacer(),
            InkWell(
              onTap: () => _openFullPicker(context, selected, onChanged),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selected,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('More colors'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (name, color) in presets)
              _swatch(
                color,
                name,
                selected,
                onChanged,
                blocked: blockedColor != null && color.toARGB32() == blockedColor.toARGB32(),
              ),
          ],
        ),
        if (isBlocked)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Can't match the other color — text would be invisible.",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: hue,
                max: 360,
                activeColor: fixedSliderColor ?? selected,
                thumbColor: fixedSliderColor ?? selected,
                onChanged: (h) => onChanged(HSLColor.fromAHSL(1, h, 0.72, 0.52).toColor()),
              ),
            ),
            if (revertColor != null)
              Tooltip(
                message: 'Revert to theme default',
                child: InkWell(
                  onTap: () => onChanged(revertColor),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/icons/revert_circle.svg',
                      width: 24,
                      height: 24,
                      // Same color on both rows, matching ordinary text —
                      // not the (opposite-of-each-other) value each icon
                      // reverts to. Uses the dialog's own onSurface (not a
                      // device-brightness guess) so it's correct even when
                      // Theme is explicitly Dark/Light rather than System.
                      colorFilter: ColorFilter.mode(
                        theme.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _swatch(
    Color color,
    String name,
    Color selected,
    ValueChanged<Color> onChanged, {
    bool blocked = false,
  }) {
    final isSelected = color.toARGB32() == selected.toARGB32();
    return Tooltip(
      message: blocked ? "$name — matches the other color" : name,
      child: InkWell(
        onTap: blocked ? null : () => onChanged(color),
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: blocked ? 0.3 : 1,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, size: 16, color: AppTheme.onAccent(color))
                : null,
          ),
        ),
      ),
    );
  }
}
