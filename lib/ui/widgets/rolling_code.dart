import 'package:flutter/material.dart';

/// Shows an OTP code in two digit groups. When the code changes, the digits
/// that differ roll over one after another, left to right, so a new code reads
/// as a deliberate handover instead of a sudden swap.
class RollingCode extends StatefulWidget {
  final String code;
  final TextStyle style;

  /// Space between the two digit groups.
  final double groupGap;

  const RollingCode({
    super.key,
    required this.code,
    required this.style,
    this.groupGap = 8,
  });

  @override
  State<RollingCode> createState() => _RollingCodeState();
}

class _RollingCodeState extends State<RollingCode>
    with SingleTickerProviderStateMixin {
  // How much of the animation each digit's start is delayed behind the last.
  static const _stagger = 0.07;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    value: 1,
  );
  String? _previous;

  @override
  void didUpdateWidget(RollingCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code == widget.code) return;
    // A different length has no digit-to-digit mapping, so just show it.
    if (oldWidget.code.length != widget.code.length ||
        MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = oldWidget.code;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _digitProgress(int index) {
    final digits = widget.code.length;
    final start = index * _stagger;
    final span = 1 - (digits - 1) * _stagger;
    final t = ((_controller.value - start) / span).clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(t);
  }

  Widget _buildDigit(int index) {
    final digit = Text(widget.code[index]);
    final previous = _previous;
    if (previous == null ||
        _controller.isCompleted ||
        previous[index] == widget.code[index]) {
      return digit;
    }
    final t = _digitProgress(index);
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          FractionalTranslation(
            translation: Offset(0, -t),
            child: Opacity(
              opacity: 1 - t,
              child: Text(previous[index]),
            ),
          ),
          FractionalTranslation(
            translation: Offset(0, 1 - t),
            child: Opacity(opacity: t, child: digit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final middle = code.length ~/ 2;
    return Semantics(
      label: code,
      child: ExcludeSemantics(
        // Animated so the color change eases too, rather than snapping.
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: widget.style,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < code.length; i++) ...[
                  if (i == middle) SizedBox(width: widget.groupGap),
                  _buildDigit(i),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
