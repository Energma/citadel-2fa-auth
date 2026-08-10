import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';

/// PIN setup screen that handles creation and confirmation of a new PIN.
/// Returns the confirmed PIN string via Navigator.pop, or null if cancelled.
class PinSetupScreen extends StatefulWidget {
  final String title;

  const PinSetupScreen({super.key, this.title = 'Set Up PIN'});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _error;

  void _onPinEntered(String pin) {
    if (_firstPin == null) {
      // First entry
      setState(() {
        _firstPin = pin;
        _error = null;
      });
    } else {
      // Confirmation
      if (pin == _firstPin) {
        Navigator.pop(context, pin);
      } else {
        setState(() {
          _firstPin = null;
          _error = "Those PINs didn't match — start again from the top.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: PinInput(
            onCompleted: _onPinEntered,
            error: _error,
            title: _firstPin == null ? 'Create your app PIN' : 'Confirm your PIN',
            subtitle: _firstPin == null
                ? "Pick a 6-digit PIN for Citadel. This is separate from your "
                    "phone's screen lock — you'll enter it to unlock the app."
                : 'Re-enter the same 6 digits to confirm.',
            submitLabel: _firstPin == null ? 'Continue' : 'Confirm PIN',
          ),
        ),
      ),
    );
  }
}

/// Confirms the vault's existing PIN via [verify], without changing it. The
/// PIN itself is never stored (see [KeystoreService.setPinEnabled]), so this
/// is how a later flow — like re-enabling biometric unlock from Settings —
/// gets it back to rebuild the encryption passphrase. Returns the PIN via
/// Navigator.pop on success, or null if cancelled.
class PinConfirmScreen extends StatefulWidget {
  final Future<bool> Function(String pin) verify;
  final String title;
  final String subtitle;

  const PinConfirmScreen({
    super.key,
    required this.verify,
    this.title = 'Confirm PIN',
    this.subtitle = 'Enter your current app PIN to continue.',
  });

  @override
  State<PinConfirmScreen> createState() => _PinConfirmScreenState();
}

class _PinConfirmScreenState extends State<PinConfirmScreen> {
  String? _error;
  bool _checking = false;

  Future<void> _onPinEntered(String pin) async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final correct = await widget.verify(pin);
    if (!mounted) return;

    if (correct) {
      Navigator.pop(context, pin);
    } else {
      setState(() {
        _checking = false;
        _error = 'Incorrect PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _checking ? null : () => Navigator.pop(context, null),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _checking
              ? const CircularProgressIndicator()
              : PinInput(
                  onCompleted: _onPinEntered,
                  error: _error,
                  title: widget.title,
                  subtitle: widget.subtitle,
                  submitLabel: 'Confirm',
                ),
        ),
      ),
    );
  }
}
