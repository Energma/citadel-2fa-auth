import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Citadel logo, in one place so every screen shows the same one and
/// changing it is a single edit.
///
/// The mark is transparent inside so it sits on any theme or custom colour:
/// white lines on dark backgrounds, black lines on light ones.
class CitadelLogo extends StatelessWidget {
  final double size;

  const CitadelLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark
          ? 'assets/logo/citadel-mark-negative.svg'
          : 'assets/logo/citadel-mark-positive.svg',
      width: size,
      height: size,
    );
  }
}
