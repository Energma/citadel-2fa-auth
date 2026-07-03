import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A numeric PIN input widget with filled dot indicators.
class PinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final String? error;
  final String title;
  final String subtitle;

  /// When non-null, a submit button with this label is shown and the PIN is
  /// only submitted when it's tapped (so the user can review/correct first).
  /// When null, the PIN auto-submits once all digits are entered — used for
  /// the fast unlock screen.
  final String? submitLabel;

  const PinInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.error,
    this.title = 'Enter PIN',
    this.subtitle = '',
    this.submitLabel,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
  }

  @override
  void didUpdateWidget(PinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shake and clear whenever a new error arrives — not just the first one.
    // Comparing values (rather than null→non-null) means a second consecutive
    // wrong PIN still resets the dots so the user can re-enter.
    if (widget.error != null && widget.error != oldWidget.error) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      setState(() => _pin = '');
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(int digit) {
    if (_pin.length >= widget.length) return;
    HapticFeedback.lightImpact();
    setState(() => _pin += digit.toString());
    // Auto-submit only when there's no explicit submit button (fast unlock).
    // Clear the entered PIN as we submit so the dots reset for the next try
    // even when the error message is identical to the previous attempt's.
    if (_pin.length == widget.length && widget.submitLabel == null) {
      final value = _pin;
      setState(() => _pin = '');
      widget.onCompleted(value);
    }
  }

  void _submit() {
    if (_pin.length != widget.length) return;
    HapticFeedback.lightImpact();
    final value = _pin;
    setState(() => _pin = '');
    widget.onCompleted(value);
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ],
        const SizedBox(height: 32),

        // PIN dots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnimation.value * (_shakeController.status == AnimationStatus.reverse ? -1 : 1), 0),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (i) {
              final filled = i < _pin.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: filled ? 16 : 14,
                  height: filled ? 16 : 14,
                  // On a wrong PIN the dots simply reset to their empty,
                  // unfilled state — the error is conveyed by the live message
                  // (and the shake) rather than by recoloring the circles red.
                  decoration: BoxDecoration(
                    color: filled
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(filled ? 255 : 80),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),

        if (widget.error != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.error!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        const SizedBox(height: 40),

        // Numeric keypad
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildKeypadRow([1, 2, 3], theme),
              const SizedBox(height: 12),
              _buildKeypadRow([4, 5, 6], theme),
              const SizedBox(height: 12),
              _buildKeypadRow([7, 8, 9], theme),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 72, height: 72),
                  _buildKeypadButton(0, theme),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      onPressed: _pin.isEmpty ? null : _deleteDigit,
                      icon: Icon(
                        Icons.backspace_rounded,
                        color: _pin.isEmpty
                            ? theme.colorScheme.onSurface.withAlpha(40)
                            : theme.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Explicit submit button (when enabled) — lets the user review and
        // correct the PIN before confirming instead of auto-submitting.
        if (widget.submitLabel != null) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: 280,
            child: ElevatedButton(
              onPressed: _pin.length == widget.length ? _submit : null,
              child: Text(widget.submitLabel!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeypadRow(List<int> digits, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, theme)).toList(),
    );
  }

  Widget _buildKeypadButton(int digit, ThemeData theme) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addDigit(digit),
          borderRadius: BorderRadius.circular(36),
          splashColor: theme.colorScheme.primary.withAlpha(30),
          child: Center(
            child: Text(
              '$digit',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
