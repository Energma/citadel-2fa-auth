import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/crypto/otp_engine.dart';
import '../../core/models/token.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'rolling_code.dart';
import 'service_icon.dart';

// Every digit takes the same width, so codes don't shift as digits change.
const _tabularDigits = [FontFeature.tabularFigures()];

class TokenCard extends StatefulWidget {
  final Token token;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<Token> Function()? onCounterIncrement;
  final VoidCallback? onMoveToProfile;

  /// Shown at the end of the header. Supplied by the parent because only it
  /// knows the card's position in the surrounding reorderable list.
  final Widget? dragHandle;

  const TokenCard({
    super.key,
    required this.token,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCounterIncrement,
    this.onMoveToProfile,
    this.dragHandle,
  });

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  String _code = '';
  String _nextCode = '';
  double _progress = 0;
  int _remaining = 0;
  bool _copied = false;
  bool _incrementing = false;

  @override
  void initState() {
    super.initState();
    _updateCode();
    if (widget.token.type == OtpType.totp) {
      _timer =
          Timer.periodic(const Duration(milliseconds: 500), (_) => _updateCode());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _incrementCounter() async {
    if (_incrementing || widget.onCounterIncrement == null) return;
    setState(() => _incrementing = true);
    try {
      final updated = await widget.onCounterIncrement!();
      if (mounted) {
        setState(() {
          _code = OtpEngine.generateCode(updated);
          _incrementing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _incrementing = false);
    }
  }

  void _updateCode() {
    if (!mounted) return;
    setState(() {
      _code = OtpEngine.generateCode(widget.token);
      if (widget.token.type == OtpType.totp) {
        _nextCode = OtpEngine.generateNextTotp(widget.token);
        _progress = OtpEngine.progress(widget.token);
        _remaining = OtpEngine.remainingSeconds(widget.token);
      }
    });
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _code));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Copied ${widget.token.issuer.isNotEmpty ? widget.token.issuer : "code"}'),
          ],
        ),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpiring = widget.token.type == OtpType.totp && _remaining <= 5;

    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.4,
        children: [
          if (widget.onEdit != null)
            SlidableAction(
              onPressed: (_) => widget.onEdit!(),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Edit',
              borderRadius: BorderRadius.circular(16),
            ),
          if (widget.onDelete != null)
            SlidableAction(
              onPressed: (_) => widget.onDelete!(),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _copyCode,
            onLongPress: widget.onMoveToProfile,
            borderRadius: BorderRadius.circular(16),
            splashColor: theme.colorScheme.primary.withAlpha(20),
            highlightColor: theme.colorScheme.primary.withAlpha(10),
            child: Ink(
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface.withAlpha(200)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                // On a dark background the card fill and shadow barely show, so
                // the border is what marks the card's edge.
                border: Border.all(
                  color: theme.colorScheme.onSurface.withAlpha(isDark ? 55 : 22),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 10),
                    _buildCodeSection(theme, isExpiring),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        _buildIcon(theme),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.token.issuer.isNotEmpty
                    ? widget.token.issuer
                    : widget.token.account,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.token.issuer.isNotEmpty) ...[
                Text(
                  widget.token.account,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(130),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (widget.token.isPinned)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.push_pin_rounded,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ),
        if (_copied) ...[
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Colors.greenAccent,
            ),
          ),
        ],
        // Visible counterpart to swipe-to-edit, which is easy to miss: the
        // edit screen is where a token changes profile, group and icon.
        if (widget.onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 18,
            tooltip: 'Edit token',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurface.withAlpha(150),
            onPressed: widget.onEdit,
          ),
        ?widget.dragHandle,
      ],
    );
  }

  Widget _buildCodeSection(ThemeData theme, bool isExpiring) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // Scales down instead of wrapping when a long (8-digit) code has to
          // share the row with the next code on a narrow screen.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollingCode(
              code: _code,
              groupGap: 9,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFeatures: _tabularDigits,
                color: isExpiring
                    ? Colors.redAccent
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (widget.token.type == OtpType.totp) ...[
          const SizedBox(width: 8),
          // Faded rather than removed, so the code keeps its place as the
          // timer crosses the 5s threshold.
          ExcludeSemantics(
            excluding: !isExpiring,
            child: AnimatedOpacity(
              opacity: isExpiring ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: _buildNextCode(theme),
            ),
          ),
          const SizedBox(width: 10),
          _buildTimer(theme, isExpiring),
        ],
        if (widget.token.type == OtpType.hotp) _buildHotpIncrement(theme),
      ],
    );
  }

  Widget _buildHotpIncrement(ThemeData theme) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: _incrementing ? null : _incrementCounter,
        icon: _incrementing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.refresh_rounded,
                color: theme.colorScheme.primary,
              ),
        tooltip: 'Next code',
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(ThemeData theme, bool isExpiring) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: 1 - _progress,
              strokeWidth: 2,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.onSurface.withAlpha(20),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          Text(
            '$_remaining',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: _tabularDigits,
              color: isExpiring
                  ? Colors.redAccent
                  : theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextCode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NEXT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: theme.colorScheme.onSurface.withAlpha(110),
          ),
        ),
        RollingCode(
          code: _nextCode,
          groupGap: 5,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFeatures: _tabularDigits,
            color: theme.colorScheme.onSurface.withAlpha(170),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(ThemeData theme) {
    return ServiceIcon(
      issuer: widget.token.issuer,
      account: widget.token.account,
      iconPath: widget.token.iconPath,
      size: 36,
    );
  }
}
