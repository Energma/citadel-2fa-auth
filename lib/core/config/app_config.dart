/// Build-time configuration flags.
///
/// All values come from `--dart-define` (or `--dart-define-from-file`), so the
/// single secure default lives here and only a *demo* build opts out of it:
///
///   Prod (full security):
///     fvm flutter build apk --dart-define-from-file=config/prod.json
///
///   Demo (everything open — screenshots/recording allowed):
///     fvm flutter build apk --dart-define-from-file=config/demo.json
///
/// With no flags at all the app behaves like a prod build, so an accidental
/// release can never ship with security relaxed.
class AppConfig {
  const AppConfig._();

  /// Demo builds relax security so the app can be captured for marketing and
  /// manual testing. Prod builds leave this `false`.
  static const bool demoMode =
      bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  /// Whether screenshots and screen recording are permitted. Blocked in prod,
  /// allowed in demo builds. Defaults to [demoMode] but can be forced on its
  /// own with `--dart-define=ALLOW_SCREENSHOTS=true`.
  static const bool allowScreenshots =
      bool.fromEnvironment('ALLOW_SCREENSHOTS', defaultValue: demoMode);
}
