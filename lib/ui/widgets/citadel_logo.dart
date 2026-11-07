import 'package:flutter/material.dart';

/// The Citadel logo, in one place so every screen shows the same one and
/// changing it is a single edit.
class CitadelLogo extends StatelessWidget {
  final double size;

  const CitadelLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/logo/citadel-logo.png', width: size, height: size);
}
