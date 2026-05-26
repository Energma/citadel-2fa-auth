import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../ui/theme/palette.dart';
import 'pin_setup_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _enableBiometric = true;
  bool _enablePin = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createVault() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    // If PIN enabled, prompt for PIN setup first
    String? pin;
    if (_enablePin && mounted) {
      pin = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (pin == null) return; // User cancelled PIN setup
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Combine password + PIN for vault passphrase
    final passphrase = pin != null ? '$password$pin' : password;
    final success = await ref.read(vaultProvider.notifier).createVault(passphrase);

    if (success) {
      final keystore = ref.read(keystoreServiceProvider);

      // Store PIN hash if PIN was set
      if (pin != null) {
        final pinHash = sha256.convert(utf8.encode(pin)).toString();
        await keystore.storePinHash(pinHash);
      }

      // Setup biometric
      if (_enableBiometric) {
        final biometric = ref.read(biometricServiceProvider);
        final available = await biometric.isAvailable();
        if (available) {
          await keystore.storeVaultKey(utf8.encode(passphrase));
          await keystore.setBiometricEnabled(true);
        }
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      if (!success) {
        setState(() => _error = 'Failed to create vault');
      }
    }
  }

  Widget _buildFooterLink(String text, String url, ThemeData theme) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/logo/citadel_logo.svg', width: 72, height: 72),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to Citadel',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a master password. Everything stays encrypted on your device.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Master password',
                          hintText: 'Enter a strong password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        onSubmitted: (_) => _createVault(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          hintText: 'Re-enter your password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Enable biometric unlock'),
                        subtitle: const Text('Use fingerprint or face to unlock'),
                        value: _enableBiometric,
                        onChanged: (v) => setState(() => _enableBiometric = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Enable PIN'),
                        subtitle: const Text('Add a 6-digit PIN as extra security factor'),
                        value: _enablePin,
                        onChanged: (v) => setState(() => _enablePin = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _createVault,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create Vault'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No cloud. No account. No telemetry.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(97),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer with legal links
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFooterLink(
                    'Privacy',
                    'https://www.energma.co/privacy-policy',
                    theme,
                  ),
                  Text(
                    ' • ',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  _buildFooterLink(
                    'Terms',
                    'https://www.energma.co/terms-of-use',
                    theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
