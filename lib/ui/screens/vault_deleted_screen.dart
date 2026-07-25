import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// Shown after a vault deletion completes: a brief confirmation message, then
/// the Energma mark, before handing off to Setup. Deleting a vault destroys
/// everything with no undo, so the transition confirms it happened instead of
/// snapping straight from Settings to a blank "create a new vault" screen.
class VaultDeletedScreen extends StatefulWidget {
  /// Called once the message+logo sequence finishes. Should flip the vault
  /// state to uninitialized; this screen pops itself (and everything above
  /// root) once that's done, so the root switch in main.dart reveals Setup.
  final Future<void> Function() onComplete;

  const VaultDeletedScreen({super.key, required this.onComplete});

  @override
  State<VaultDeletedScreen> createState() => _VaultDeletedScreenState();
}

class _VaultDeletedScreenState extends State<VaultDeletedScreen> {
  static const _messageDuration = Duration(milliseconds: 1400);
  static const _logoDuration = Duration(milliseconds: 1400);

  bool _showLogo = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(_messageDuration);
    if (!mounted) return;
    setState(() => _showLogo = true);

    await Future.delayed(_logoDuration);
    await widget.onComplete();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.splashBg,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showLogo
              ? Image.asset(
                  'assets/logo/energma_logo.png',
                  key: const ValueKey('logo'),
                  width: 80,
                  height: 80,
                  color: Colors.white,
                )
              : Padding(
                  key: const ValueKey('message'),
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Palette.accent, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'You deleted your Vault successfully.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
