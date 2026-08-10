import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'core/config/app_config.dart';
import 'core/models/theme_settings.dart';
import 'core/providers.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prod builds block screenshots + screen recording and hide the app's
  // contents in the recents/app-switcher thumbnail. Demo builds set
  // ALLOW_SCREENSHOTS=true (via config/demo.json) so the app can be captured.
  if (!AppConfig.allowScreenshots) {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithBlur();
  }

  final container = ProviderContainer();
  await loadPersistedSettings(container);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const CitadelApp(),
  ));
}

class CitadelApp extends ConsumerStatefulWidget {
  const CitadelApp({super.key});

  @override
  ConsumerState<CitadelApp> createState() => _CitadelAppState();
}

class _CitadelAppState extends ConsumerState<CitadelApp> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vaultProvider.notifier).checkStatus());
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final citadelThemeMode = ref.watch(citadelThemeModeProvider);

    // ThemeMode has no "custom" slot, so a custom theme is pinned in place
    // by handing it to MaterialApp as both theme and darkTheme with a fixed
    // ThemeMode.light — that sidesteps Flutter's light/dark resolution
    // entirely instead of fighting it.
    final ThemeData lightTheme;
    final ThemeData darkTheme;
    final ThemeMode themeMode;
    if (citadelThemeMode == CitadelThemeMode.custom) {
      final customTheme = AppTheme.customTheme(ref.watch(customThemeColorsProvider));
      lightTheme = customTheme;
      darkTheme = customTheme;
      themeMode = ThemeMode.light;
    } else {
      lightTheme = AppTheme.lightTheme();
      darkTheme = AppTheme.darkTheme();
      themeMode = switch (citadelThemeMode) {
        CitadelThemeMode.light => ThemeMode.light,
        CitadelThemeMode.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }

    return MaterialApp(
      title: 'Citadel Auth',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: !_splashDone
          ? SplashScreen(onComplete: () => setState(() => _splashDone = true))
          : switch (vault.status) {
              VaultStatus.uninitialized => const SetupScreen(),
              VaultStatus.locked => const LockScreen(),
              VaultStatus.unlocked => const HomeScreen(),
            },
    );
  }
}
