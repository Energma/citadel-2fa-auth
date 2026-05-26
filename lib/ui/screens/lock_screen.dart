import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../ui/theme/palette.dart';
import '../widgets/pin_input.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _showPinInput = false;
  String? _pendingPassphrase;
  String? _pinError;
  int _pinAttempts = 0;
  bool _pinLocked = false;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final biometric = ref.read(biometricServiceProvider);
    final keystore = ref.read(keystoreServiceProvider);

    final enabled = await keystore.isBiometricEnabled();
    if (!enabled) return;

    final available = await biometric.isAvailable();
    if (!available) return;

    final success = await biometric.authenticate();
    if (success && mounted) {
      final key = await keystore.getVaultKey();
      if (key != null) {
        // The stored key is the full passphrase (password+pin) encoded as UTF-8
        final passphrase = String.fromCharCodes(key);
        await _unlock(passphrase);
      }
    }
  }

  Future<void> _handlePasswordSubmit() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    await _unlock(password);
  }

  Future<void> _handlePinCompleted(String pin) async {
    if (_pendingPassphrase == null) return;

    // Check lockout status
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      setState(() => _pinError = 'Too many attempts. Try again in 30 seconds.');
      return;
    }

    // Validate PIN hash first (fast check)
    final keystore = ref.read(keystoreServiceProvider);
    final storedHash = await keystore.getPinHash();
    final enteredHash = sha256.convert(utf8.encode(pin)).toString();

    if (storedHash != null && storedHash != enteredHash) {
      _pinAttempts++;
      if (_pinAttempts >= 5) {
        setState(() {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _pinLocked = true;
          _pinError = 'Too many wrong attempts. Try again in 30 seconds.';
        });
      } else {
        setState(() => _pinError = 'Wrong PIN (${5 - _pinAttempts} attempts left)');
      }
      return;
    }

    // PIN valid, combine with password for vault unlock
    final fullPassphrase = '$_pendingPassphrase$pin';
    final success = await ref.read(vaultProvider.notifier).unlock(fullPassphrase);

    if (mounted) {
      if (!success) {
        setState(() {
          _pinError = 'Failed to unlock vault';
          _showPinInput = false;
          _pendingPassphrase = null;
          _error = 'Wrong password or PIN combination';
          _pinAttempts = 0;
          _pinLocked = false;
          _lockoutUntil = null;
        });
      }
    }
  }

  Future<void> _unlock(String passphrase) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref.read(vaultProvider.notifier).unlock(passphrase);

    if (mounted) {
      setState(() => _loading = false);
      if (!success) {
        setState(() => _error = 'Wrong password. Please try again.');
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
                child: _showPinInput
                    ? _buildPinView(theme)
                    : _buildPasswordView(theme),
              ),
            ),
            // Footer with links and Powered by Energma
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: 12),
                  Text(
                    'Powered by',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Palette.primary, Palette.accent],
                        ).createShader(bounds),
                        child: const Icon(Icons.bolt, size: 20, color: Colors.white),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/logo/citadel_logo.svg', width: 72, height: 72),
          const SizedBox(height: 16),
          Text(
            'Citadel Auth',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock your vault',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) => _handlePasswordSubmit(),
            decoration: InputDecoration(
              labelText: 'Master Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              errorText: _error,
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(100),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(80),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _handlePasswordSubmit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unlock'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinView(ThemeData theme) {
    return PinInput(
      onCompleted: _handlePinCompleted,
      error: _pinError,
      title: 'Enter PIN',
      subtitle: 'Enter your 6-digit PIN to unlock',
    );
  }
}
