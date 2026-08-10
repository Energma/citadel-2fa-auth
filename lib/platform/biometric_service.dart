import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// True only when there's real fingerprint/face hardware with something
  /// enrolled — unlike [isAvailable], a plain PIN/pattern/password screen
  /// lock with no biometric sensor does NOT count. Use this to gate anything
  /// that claims to be a biometric scan; use [isAvailable] for "any device
  /// credential will do" (the phone's screen lock as a whole).
  Future<bool> hasBiometricHardware() async {
    final available = await getAvailableBiometrics();
    return available.isNotEmpty;
  }

  Future<bool> authenticate({String reason = 'Unlock Citadel Auth'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
