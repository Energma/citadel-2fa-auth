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
