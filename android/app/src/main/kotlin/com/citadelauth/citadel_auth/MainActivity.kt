package com.citadelauth.citadel_auth

import io.flutter.embedding.android.FlutterFragmentActivity

// FLAG_SECURE is deliberately NOT set here. Setting it natively in onCreate ran
// before Dart and could never be lifted, which made AppConfig.allowScreenshots
// and the demo build profile dead code — demo builds still could not be
// captured. Dart owns the flag now: main() calls ScreenProtector for every
// build except demo, and AppConfig defaults to secure when no flags are passed.
class MainActivity : FlutterFragmentActivity()
