import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../ui/theme/palette.dart';
import '../widgets/pin_input.dart';

/// The one unlock method the screen is currently showing. Exactly one primary
/// view renders at a time — the others are reachable through flat fallback
/// links, never stacked on the same screen.
///
/// [biometric] is true fingerprint/face unlock layered on an app PIN;
/// [deviceCredential] is the phone's own screen lock (PIN/pattern/biometric
/// via the OS) with no separate app PIN. Both drive the same native prompt
/// via [BiometricService], but render different waiting views since only
/// [biometric] is guaranteed to actually be a fingerprint/face scan.
enum _UnlockMethod { biometric, deviceCredential, pin, password }

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
  String? _pinError;
  bool _pinEnabled = false;
  bool _biometricUsable = false;
  bool _initialized = false;

  /// What the user actually unlocks with day-to-day; fallback links always
  /// offer a way back here so a mis-tap can't strand them on the password form.
  _UnlockMethod _primaryMethod = _UnlockMethod.password;
  _UnlockMethod _method = _UnlockMethod.password;

  @override
  void initState() {
    super.initState();
    _initializeLockState();
  }

  static const _maxAttemptsBeforeLockout = 5;

  /// Work out which unlock method this device actually has before rendering, so
  /// we never flash the master password screen at someone who unlocks with a
  /// fingerprint. The password is a deliberate fallback, not the default.
  Future<void> _initializeLockState() async {
    final keystore = ref.read(keystoreServiceProvider);
    final biometric = ref.read(biometricServiceProvider);

    final pinEnabled = await keystore.isPinEnabled();
    final unlockMethod = await keystore.getUnlockMethod();
    // Enabled in settings is not enough — the device must still be able to do
    // it (credential removed, biometrics unenrolled).
    final credentialUsable = (unlockMethod == 'biometric' ||
            unlockMethod == 'deviceCredential') &&
        await biometric.isAvailable();

    if (!mounted) return;
    setState(() {
      _pinEnabled = pinEnabled;
      _biometricUsable = credentialUsable;
      _primaryMethod = !credentialUsable
          ? (pinEnabled ? _UnlockMethod.pin : _UnlockMethod.password)
          : unlockMethod == 'deviceCredential'
              ? _UnlockMethod.deviceCredential
              : _UnlockMethod.biometric;
      _method = _primaryMethod;
      _initialized = true;
    });

    if (credentialUsable) await _tryBiometric();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Prompt for the device credential. Safe to call again — cancelling just
  /// leaves the user on the lock screen with the fingerprint button still there.
  Future<void> _tryBiometric() async {
    final biometric = ref.read(biometricServiceProvider);
    final keystore = ref.read(keystoreServiceProvider);

    final success = await biometric.authenticate();
    if (!success || !mounted) return;

    final key = await keystore.getVaultKey();
    if (key == null) {
      // The scan succeeded but there is no stored key to unlock with — say so
      // instead of silently doing nothing, and point at the fallback.
      setState(() => _error = 'Biometric unlock is unavailable. '
          'Use your ${_pinEnabled ? 'PIN' : 'master password'} instead.');
      return;
    }

    // The stored key is the full passphrase (password+pin) encoded as UTF-8 —
    // decode it the same way or non-ASCII passphrases fail to round-trip.
    final unlocked = await _unlock(utf8.decode(key));
    if (!unlocked && mounted) {
      // The stored key no longer opens the vault (e.g. a restored backup keyed
      // with a different passphrase). Retrying the sensor can't fix that, so
      // replace the generic wrong-password message with a pointer to the
      // fallback method.
      setState(() => _error = 'Fingerprint accepted, but the stored key no '
          'longer matches this vault. '
          'Use your ${_pinEnabled ? 'PIN' : 'master password'} instead.');
    }
  }

  Future<void> _handlePasswordSubmit() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    await _unlock(password);
  }

  Future<void> _handlePinCompleted(String pin) async {
    if (_loading) return; // a previous attempt is still deriving the key

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

    // Mark the attempt in-flight so the fallback links stay disabled — a view
    // switch mid-attempt would land the wrong-PIN/lockout message on a view
    // that never renders it.
    setState(() => _loading = true);
    try {
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _unlock(String passphrase) async {
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
    return success;
  }

  /// Switching views is purely local — no method is enabled or disabled, the
  /// user just picks which credential to present.
  void _switchTo(_UnlockMethod method) {
    setState(() {
      _method = method;
      _error = null;
      _pinError = null;
    });
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
                child: !_initialized
                    ? const CircularProgressIndicator()
                    : switch (_method) {
                        _UnlockMethod.biometric => _buildBiometricView(theme),
                        _UnlockMethod.deviceCredential =>
                          _buildDeviceCredentialView(theme),
                        _UnlockMethod.pin => _buildPinView(theme),
                        _UnlockMethod.password => _buildPasswordView(theme),
                      },
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

  /// Logo + app name shared by the biometric and password views, so switching
  /// between them doesn't visually reflow the top of the screen.
  List<Widget> _buildHeader(ThemeData theme, String subtitle) {
    return [
      Image.asset('assets/logo/citadel-logo.png', width: 72, height: 72),
      const SizedBox(height: 16),
      Text(
        'Citadel Auth',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(153),
        ),
      ),
    ];
  }

  /// A flat, low-emphasis link for hopping between unlock methods. These are
  /// escape hatches, not calls to action — a heavy button would compete with
  /// the primary unlock control above it.
  Widget _buildSwitchLink(String label, _UnlockMethod target) {
    return TextButton(
      onPressed: _loading ? null : () => _switchTo(target),
      child: Text(label),
    );
  }

  Widget _buildBiometricView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._buildHeader(theme, 'Unlock your vault'),
          const SizedBox(height: 48),
          // The automatic prompt on open can be cancelled or mis-scanned; the
          // big fingerprint is the obvious way to try again without restarting.
          IconButton(
            onPressed: _loading ? null : _tryBiometric,
            iconSize: 64,
            padding: const EdgeInsets.all(20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withAlpha(20),
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.fingerprint),
          ),
          const SizedBox(height: 16),
          Text(
            'Touch the sensor to unlock',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 32),
          // With a PIN enabled the vault passphrase is password+PIN, so the
          // password view can't work (and would sidestep the persisted PIN
          // lockout) — PIN is the only knowledge fallback in that case.
          if (_pinEnabled)
            _buildSwitchLink('Use PIN', _UnlockMethod.pin)
          else
            _buildSwitchLink('Use master password', _UnlockMethod.password),
        ],
      ),
    );
  }

  /// Same native prompt as [_buildBiometricView], but for the "phone's screen
  /// lock" method the prompt may end up being a PIN/pattern entry rather than
  /// a sensor scan — so no fingerprint icon is shown here, unlike the true
  /// biometric view, to avoid flashing a misleading graphic before the actual
  /// OS prompt appears.
  Widget _buildDeviceCredentialView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._buildHeader(theme, 'Unlock your vault'),
          const SizedBox(height: 48),
          IconButton(
            onPressed: _loading ? null : _tryBiometric,
            iconSize: 64,
            padding: const EdgeInsets.all(20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withAlpha(20),
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.lock_open_rounded),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm using your device screen lock',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 32),
          // No app PIN exists for this method — the master password is the
          // only other way in.
          _buildSwitchLink('Use master password', _UnlockMethod.password),
        ],
      ),
    );
  }

  Widget _buildPinView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinInput(
          onCompleted: _handlePinCompleted,
          error: _pinError,
          title: 'Enter PIN',
          subtitle: 'Enter your 6-digit PIN to unlock',
        ),
        const SizedBox(height: 12),
        // No master-password fallback here: with a PIN enabled the vault
        // passphrase is password+PIN, so the password alone can never unlock —
        // and a free-form field would let wrong-PIN guesses (password+guess)
        // bypass the persisted PIN lockout entirely.
        if (_biometricUsable)
          TextButton.icon(
            onPressed: _loading ? null : _tryBiometric,
            icon: const Icon(Icons.fingerprint, size: 20),
            label: const Text('Use biometrics'),
          ),
        // Biometric attempts started from this view report through _error;
        // _pinError (rendered inside PinInput) is for PIN attempts only.
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._buildHeader(theme, 'Unlock your vault'),
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
          // A way back to the everyday method when the password form was only
          // reached as a fallback.
          if (_primaryMethod != _UnlockMethod.password) ...[
            const SizedBox(height: 16),
            _buildSwitchLink(
              switch (_primaryMethod) {
                _UnlockMethod.biometric => 'Use biometrics',
                _UnlockMethod.deviceCredential => 'Use device screen lock',
                _UnlockMethod.pin => 'Use PIN',
                _UnlockMethod.password => 'Use master password',
              },
              _primaryMethod,
            ),
          ],
        ],
      ),
    );
  }
}
