import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/database/vault_database.dart';
import '../data/repositories/token_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../platform/biometric_service.dart';
import '../platform/keystore_service.dart';
import '../ui/theme/palette.dart';
import 'models/token.dart';
import 'models/profile.dart';

// --- Singletons ---

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) => VaultDatabase());
final keystoreServiceProvider = Provider<KeystoreService>((ref) => KeystoreService());
final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  return TokenRepository(ref.watch(vaultDatabaseProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(vaultDatabaseProvider));
});

// --- Vault State ---

enum VaultStatus { uninitialized, locked, unlocked }

class VaultState {
  final VaultStatus status;
  VaultState(this.status);
}

class VaultNotifier extends StateNotifier<VaultState> {
  final VaultDatabase _db;

  VaultNotifier(this._db) : super(VaultState(VaultStatus.uninitialized));

  Future<void> checkStatus() async {
    final exists = await _db.exists();
    state = VaultState(exists ? VaultStatus.locked : VaultStatus.uninitialized);
  }

  Future<bool> createVault(String passphrase) async {
    try {
      await _db.open(passphrase);
      state = VaultState(VaultStatus.unlocked);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock(String passphrase) async {
    try {
      await _db.open(passphrase);
      state = VaultState(VaultStatus.unlocked);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> lock() async {
    await _db.close();
    state = VaultState(VaultStatus.locked);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref.watch(vaultDatabaseProvider));
});

// --- Active Profile ---

final activeProfileIdProvider = StateProvider<String?>((ref) => null);

// --- Token List ---

final tokenListProvider = FutureProvider<List<Token>>((ref) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];

  final repo = ref.read(tokenRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  if (profileId != null) {
    return repo.getByProfile(profileId);
  }
  return repo.getAll();
});

// --- Profile List ---

final profileListProvider = FutureProvider<List<Profile>>((ref) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];
  return ref.read(profileRepositoryProvider).getAll();
});

// --- Group List ---

final groupListProvider = FutureProvider<List<TokenGroup>>((ref) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];

  final repo = ref.read(profileRepositoryProvider);
  final activeProfileId = ref.watch(activeProfileIdProvider);

  // No active profile means "All profiles" — match tokenListProvider and show
  // every group, otherwise grouped tokens have no section to render into.
  if (activeProfileId == null) return repo.getAllGroups();

  return repo.getGroupsByProfile(activeProfileId);
});

/// Groups for one specific profile, independent of the active profile. The
/// Profiles & Groups screen picks a profile from a dropdown, so it can't use
/// [groupListProvider] — and it needs something invalidatable, or the list goes
/// stale the moment a group is added.
final groupsByProfileProvider =
    FutureProvider.family<List<TokenGroup>, String>((ref, profileId) async {
  final vault = ref.watch(vaultProvider);
  if (vault.status != VaultStatus.unlocked) return [];
  return ref.read(profileRepositoryProvider).getGroupsByProfile(profileId);
});

// --- Search ---

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Token>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(tokenRepositoryProvider).search(query);
});

// --- App version ---

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

// --- Biometric ---

final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(keystoreServiceProvider).isBiometricEnabled();
});

// --- PIN ---

final pinEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(keystoreServiceProvider).isPinEnabled();
});

// --- Settings (persisted) ---

final autoLockDurationProvider = StateProvider<Duration>((ref) => const Duration(minutes: 5));

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Personal Theme accent. Drives buttons, chips and highlights; surfaces keep
/// the house palette. Defaults to the brand color until the user picks one.
final accentColorProvider = StateProvider<Color>((ref) => Palette.primary);

/// Load persisted settings from keystore on app start.
Future<void> loadPersistedSettings(ProviderContainer container) async {
  final keystore = container.read(keystoreServiceProvider);

  final minutes = await keystore.getAutoLockMinutes();
  container.read(autoLockDurationProvider.notifier).state = Duration(minutes: minutes);

  final themeStr = await keystore.getThemeMode();
  container.read(themeModeProvider.notifier).state = switch (themeStr) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  final accent = await keystore.getAccentColor();
  if (accent != null) {
    container.read(accentColorProvider.notifier).state = Color(accent);
  }
}
