import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/database/vault_database.dart';
import '../data/repositories/token_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../platform/biometric_service.dart';
import '../platform/keystore_service.dart';
import 'models/token.dart';
import 'models/profile.dart';
import 'models/theme_settings.dart';

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

// Derived from the unlock method rather than the legacy standalone flag, so
// this reflects true biometric unlock only — never the device-credential
// case, which has its own provider below.
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  final method = await ref.read(keystoreServiceProvider).getUnlockMethod();
  return method == 'biometric';
});

final deviceCredentialEnabledProvider = FutureProvider<bool>((ref) async {
  final method = await ref.read(keystoreServiceProvider).getUnlockMethod();
  return method == 'deviceCredential';
});

// --- PIN ---

final pinEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(keystoreServiceProvider).isPinEnabled();
});

// --- Settings (persisted) ---

final autoLockDurationProvider = StateProvider<Duration>((ref) => const Duration(minutes: 5));

final citadelThemeModeProvider =
    StateProvider<CitadelThemeMode>((ref) => CitadelThemeMode.system);

/// Colors backing [CitadelThemeMode.custom]. Ignored in every other mode.
final customThemeColorsProvider =
    StateProvider<CustomThemeColors>((ref) => CustomThemeColors.defaults);

/// Position of the synthetic "General" section on the Home screen's "All"
/// tab, where it pools ungrouped tokens across every profile and so can't be
/// stored on a single profile row like [Profile.generalSortOrder]. Device-
/// level UI preference, not vault content.
final allViewGeneralSortOrderProvider = StateProvider<int>((ref) => -1);

/// Load persisted settings from keystore on app start.
Future<void> loadPersistedSettings(ProviderContainer container) async {
  final keystore = container.read(keystoreServiceProvider);

  final minutes = await keystore.getAutoLockMinutes();
  container.read(autoLockDurationProvider.notifier).state = Duration(minutes: minutes);

  final themeStr = await keystore.getThemeMode();
  container.read(citadelThemeModeProvider.notifier).state = switch (themeStr) {
    'light' => CitadelThemeMode.light,
    'dark' => CitadelThemeMode.dark,
    'custom' => CitadelThemeMode.custom,
    _ => CitadelThemeMode.system,
  };

  final background = await keystore.getCustomBackgroundColor();
  final text = await keystore.getCustomTextColor();
  final element = await keystore.getCustomElementColor();
  if (background != null || text != null || element != null) {
    final defaults = CustomThemeColors.defaults;
    container.read(customThemeColorsProvider.notifier).state = CustomThemeColors(
      background: background != null ? Color(background) : defaults.background,
      text: text != null ? Color(text) : defaults.text,
      element: element != null ? Color(element) : defaults.element,
    );
  }

  final allViewGeneralOrder = await keystore.getAllViewGeneralSortOrder();
  container.read(allViewGeneralSortOrderProvider.notifier).state =
      allViewGeneralOrder;
}
