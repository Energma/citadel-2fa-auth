import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'core/config/app_config.dart';
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
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Citadel Auth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(accent),
      darkTheme: AppTheme.darkTheme(accent),
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
