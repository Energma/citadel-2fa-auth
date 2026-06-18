import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _initializePinState();
    _tryBiometric();
  }

  static const _maxAttemptsBeforeLockout = 5;

  Future<void> _initializePinState() async {
    final pinEnabled = await ref.read(keystoreServiceProvider).isPinEnabled();
    if (!mounted) return;
    setState(() => _showPinInput = pinEnabled); // Show PIN pad if enabled
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
    final keystore = ref.read(keystoreServiceProvider);

    // Enforce the persisted lockout (survives app restarts, so it can't be
    // bypassed by force-quitting and reopening the app).
    final lockout = await keystore.getPinLockoutUntil();
    if (lockout != null && DateTime.now().isBefore(lockout)) {
      final secs = lockout.difference(DateTime.now()).inSeconds + 1;
      setState(() => _pinError = 'Too many attempts. Try again in ${secs}s.');
      return;
    }

    final masterPassword = await keystore.getMasterPassword();
    if (masterPassword == null) {
      setState(() =>
          _pinError = 'Setup incomplete — please reinstall and set up again.');
      return;
    }

    // The PIN is never stored. Whether it decrypts the vault IS the check —
    // and the Argon2id key derivation makes each attempt deliberately slow.
    final success =
        await ref.read(vaultProvider.notifier).unlock('$masterPassword$pin');
    if (!mounted) return;

    if (success) {
      await keystore.resetPinLockout(); // vault state flips to unlocked
      return;
    }

    // Wrong PIN — increment the persisted counter and apply an escalating
    // lockout once the threshold is crossed.
    final attempts = await keystore.getPinAttempts() + 1;
    await keystore.setPinAttempts(attempts);
    final over = attempts - _maxAttemptsBeforeLockout;
    if (over >= 0) {
      // 30s, 60s, 120s, … capped at 30 minutes.
      final secs = (30 * (1 << over.clamp(0, 16))).clamp(30, 1800);
      final until = DateTime.now().add(Duration(seconds: secs));
      await keystore.setPinLockoutUntil(until);
      if (!mounted) return;
      setState(() =>
          _pinError = 'Too many wrong attempts. Locked for ${secs}s.');
    } else {
      if (!mounted) return;
      setState(() => _pinError =
          'Wrong PIN — ${_maxAttemptsBeforeLockout - attempts} attempt(s) left.');
    }
  }

  Future<void> _unlock(String passphrase) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref.read(vaultProvider.notifier).unlock(passphrase);

    if (success) {
      // Without a PIN the unlock passphrase is the master password itself —
      // persist it so vaults created before it was stored can still verify
      // master-password confirmations.
      final keystore = ref.read(keystoreServiceProvider);
      if (!await keystore.isPinEnabled()) {
        await keystore.storeMasterPassword(passphrase);
      }
    }

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
