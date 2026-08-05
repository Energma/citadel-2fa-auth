import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import 'pin_setup_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

/// How the user unlocks the vault after setup.
enum UnlockMethod {
  /// A 6-digit PIN unique to Citadel, mixed into the encryption key.
  appPin,

  /// The phone's own screen lock (PIN / pattern / biometric). No app PIN;
  /// the encryption key is derived from the master password alone.
  deviceLock,
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _enableBiometric = true;
  UnlockMethod _method = UnlockMethod.appPin;
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

    if (_method == UnlockMethod.appPin) {
      await _createWithAppPin(password);
    } else {
      await _createWithDeviceLock(password);
    }
  }

  /// App-PIN unlock: a 6-digit PIN is combined with the master password to form
  /// the vault passphrase, so the PIN is a real factor in the encryption key.
  Future<void> _createWithAppPin(String password) async {
    if (!mounted) return;
    // Creating the vault below unlocks it, which triggers app-level
    // navigation away from this screen — disposing it — before this
    // function finishes. Read providers through the container (which
    // outlives this widget) rather than `ref` from this point on.
    final container = ProviderScope.containerOf(context, listen: false);
    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin == null) return; // Cancelled PIN setup — abort vault creation

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final passphrase = '$password$pin';
    final success =
        await container.read(vaultProvider.notifier).createVault(passphrase);

    if (success) {
      final keystore = container.read(keystoreServiceProvider);
      await keystore.storeMasterPassword(password);
      // The PIN is part of the passphrase above; we only record that PIN unlock
      // is enabled — the PIN itself is never stored.
      await keystore.setPinEnabled(true);

      // Optional biometric convenience on top of the PIN. Requires real
      // fingerprint/face hardware — isAvailable() alone would also pass for
      // a device with nothing but a PIN/pattern screen lock, which isn't
      // "biometric" and would flash a fingerprint prompt that can never work.
      var usesBiometric = false;
      if (_enableBiometric) {
        final biometric = container.read(biometricServiceProvider);
        if (await biometric.hasBiometricHardware()) {
          await keystore.storeVaultKey(utf8.encode(passphrase));
          await keystore.setBiometricEnabled(true);
          usesBiometric = true;
        }
      }
      await keystore.setUnlockMethod(usesBiometric ? 'biometric' : 'pin');
      // Refresh the cached flags — a vault deleted and recreated earlier in
      // this app session would otherwise leave the Settings screen showing
      // whatever PIN/biometric state the previous vault had.
      container.invalidate(pinEnabledProvider);
      container.invalidate(biometricEnabledProvider);
      container.invalidate(deviceCredentialEnabledProvider);
    }

    if (mounted) {
      setState(() => _loading = false);
      if (!success) setState(() => _error = 'Failed to create vault');
    }
  }

  /// Device-lock unlock: no app PIN. The phone's screen lock (PIN / pattern /
  /// biometric) gates access; the vault key is derived from the master password
  /// alone and unlocked via the stored vault key after device authentication.
  Future<void> _createWithDeviceLock(String password) async {
    // Creating the vault below unlocks it, which triggers app-level
    // navigation away from this screen — disposing it — before this
    // function finishes. Read providers through the container (which
    // outlives this widget) rather than `ref` from this point on.
    final container = ProviderScope.containerOf(context, listen: false);
    final biometric = container.read(biometricServiceProvider);
    if (!await biometric.isAvailable()) {
      if (mounted) {
        setState(() => _error =
            'No screen lock found on this phone. Set one up in your phone '
            'settings, or choose a 6-digit app PIN instead.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final success =
        await container.read(vaultProvider.notifier).createVault(password);

    if (success) {
      final keystore = container.read(keystoreServiceProvider);
      await keystore.storeMasterPassword(password);
      // No PIN hash — pinEnabled stays false. The stored vault key lets the
      // lock screen unlock after the device-credential prompt succeeds.
      await keystore.storeVaultKey(utf8.encode(password));
      // Device-credential unlock, not biometric — setUnlockMethod below is
      // what the lock screen and Settings actually branch on. Do NOT also
      // set the biometric flag here: the two are separate unlock methods.
      await keystore.setUnlockMethod('deviceCredential');
      // See the matching comment in _createWithAppPin — without this, a
      // stale cached PIN/biometric flag from a previously deleted vault
      // would leak into this new vault's Settings screen.
      container.invalidate(pinEnabledProvider);
      container.invalidate(biometricEnabledProvider);
      container.invalidate(deviceCredentialEnabledProvider);
    }

    if (mounted) {
      setState(() => _loading = false);
      if (!success) setState(() => _error = 'Failed to create vault');
    }
  }

  Widget _buildMethodTile(
    ThemeData theme, {
    required UnlockMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _method == method;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _method = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(80),
            width: selected ? 2 : 1,
          ),
          color: selected ? theme.colorScheme.primary.withAlpha(20) : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(153)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153))),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(120),
            ),
          ],
        ),
      ),
    );
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
                      Image.asset('assets/logo/citadel-logo.png', width: 72, height: 72),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to Citadel',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a master password and a PIN. Everything stays encrypted on your device.',
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
                          labelText: 'Master Password',
                          hintText: 'Min. 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        onSubmitted: (_) => _createVault(),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Re-enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'How do you want to unlock?',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMethodTile(
                        theme,
                        method: UnlockMethod.appPin,
                        icon: Icons.pin_outlined,
                        title: '6-digit app PIN',
                        subtitle: 'Recommended. A PIN unique to Citadel, mixed '
                            'into your encryption key for extra protection.',
                      ),
                      const SizedBox(height: 8),
                      _buildMethodTile(
                        theme,
                        method: UnlockMethod.deviceLock,
                        icon: Icons.phonelink_lock_outlined,
                        title: "Use my phone's screen lock",
                        subtitle: 'Unlock with your phone PIN, pattern, or '
                            'biometrics. Convenient — no separate app PIN.',
                      ),
                      if (_method == UnlockMethod.appPin) ...[
                        const SizedBox(height: 4),
                        SwitchListTile(
                          title: const Text('Also allow biometric unlock'),
                          subtitle:
                              const Text('Use fingerprint or face instead of the PIN'),
                          value: _enableBiometric,
                          onChanged: (v) => setState(() => _enableBiometric = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
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
