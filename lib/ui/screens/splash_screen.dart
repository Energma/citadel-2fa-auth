import 'package:flutter/material.dart';

/// Launch intro, mirroring the Energma desktop splash: the mark lifts in, the
/// wordmark wipes left→right, a sheen sweeps across it, then the whole thing
/// fades to reveal the app. Deliberately monochrome — no brand color here.
///
/// Colors follow the active theme's surface/onSurface roles rather than a
/// fixed palette, so it renders dark (white-on-black), light (black-on-white)
/// or the user's custom background/text pair, matching whatever [AppTheme]
/// variant [MaterialApp] has already resolved by the time this builds.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Same beats as the desktop splash: .9s lift, 1.05s wipe (after .12s), the
  // whole thing held to 1.9s, then a .55s fade out.
  static const _total = Duration(milliseconds: 2450);
  static const _ease = Cubic(0.2, 0.7, 0.2, 1);

  late final AnimationController _controller;
  late final Animation<double> _lift;
  late final Animation<double> _wipe;
  late final Animation<double> _sheen;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);

    _lift = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.367, curve: _ease),
    );
    _wipe = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.049, 0.478, curve: _ease),
    );
    _sheen = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.478, 0.78, curve: Curves.easeInOut),
    );
    _fadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.776, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = colorScheme.surface;
    final foreground = colorScheme.onSurface;

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _lift.value * _fadeOut.value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - _lift.value)),
                child: Transform.scale(
                  scale: 0.985 + 0.015 * _lift.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo/energma_logo.png',
                        width: 80,
                        height: 80,
                        color: foreground,
                      ),
                      const SizedBox(height: 20),
                      _wordmark(foreground),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The wordmark, revealed by a left→right wipe with a sheen sweeping after it.
  Widget _wordmark(Color foreground) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: _wipe.value.clamp(0.0001, 1.0),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Ride a highlight band across the text once the wipe has landed.
            final x = -0.3 + _sheen.value * 1.6;
            final dim = foreground.withValues(alpha: 0.7);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [dim, foreground, dim],
              stops: [
                (x - 0.15).clamp(0.0, 1.0),
                x.clamp(0.0, 1.0),
                (x + 0.15).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            'ENERGMA',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
