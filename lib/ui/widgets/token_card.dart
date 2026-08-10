import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/crypto/otp_engine.dart';
import '../../core/models/token.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'service_icon.dart';

class TokenCard extends StatefulWidget {
  final Token token;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<Token> Function()? onCounterIncrement;
  final VoidCallback? onMoveToProfile;

  const TokenCard({
    super.key,
    required this.token,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCounterIncrement,
    this.onMoveToProfile,
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

  String _formatCode(String code) {
    if (code.length <= 3) return code;
    final mid = code.length ~/ 2;
    return '${code.substring(0, mid)}  ${code.substring(mid)}';
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _copyCode,
            onLongPress: widget.onMoveToProfile,
            borderRadius: BorderRadius.circular(20),
            splashColor: theme.colorScheme.primary.withAlpha(20),
            highlightColor: theme.colorScheme.primary.withAlpha(10),
            child: Ink(
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface.withAlpha(200)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isExpiring
                      ? Colors.redAccent.withAlpha(60)
                      : theme.colorScheme.onSurface.withAlpha(8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha(40)
                        : Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 16),
                    _buildCodeSection(theme, isExpiring),
                    if (widget.token.type == OtpType.totp) ...[
                      const SizedBox(height: 8),
                      // Space for the next-code row is always reserved (not just
                      // when expiring) so the card height never changes as the
                      // timer crosses the 5s threshold.
                      Visibility(
                        visible: isExpiring,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: _buildNextCode(theme),
                      ),
                    ],
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
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.token.issuer.isNotEmpty
                    ? widget.token.issuer
                    : widget.token.account,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.token.issuer.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.token.account,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                    letterSpacing: 0.1,
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
        if (!_copied && (widget.onEdit != null || widget.onDelete != null))
          Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withAlpha(30),
          ),
      ],
    );
  }

  Widget _buildCodeSection(ThemeData theme, bool isExpiring) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _formatCode(_code),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontFamily: 'monospace',
              color: isExpiring
                  ? Colors.redAccent
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (widget.token.type == OtpType.totp) _buildTimer(theme, isExpiring),
        if (widget.token.type == OtpType.hotp) _buildHotpIncrement(theme),
      ],
    );
  }

  Widget _buildHotpIncrement(ThemeData theme) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
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
    final color =
        isExpiring ? Colors.redAccent : theme.colorScheme.primary;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: 1 - _progress,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              backgroundColor:
                  theme.colorScheme.onSurface.withAlpha(20),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$_remaining',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextCode(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.skip_next_rounded,
          size: 16,
          color: theme.colorScheme.onSurface.withAlpha(80),
        ),
        const SizedBox(width: 4),
        Text(
          _formatCode(_nextCode),
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withAlpha(80),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(ThemeData theme) {
    return ServiceIcon(
      issuer: widget.token.issuer,
      account: widget.token.account,
      size: 44,
    );
  }
}
