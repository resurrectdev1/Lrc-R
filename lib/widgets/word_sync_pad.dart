import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/lrc_theme.dart';
import '../theme/motion.dart';

class WordSyncPads extends StatelessWidget {
  final LrcTheme theme;
  final bool enabled;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onNext;

  const WordSyncPads({
    super.key,
    required this.theme,
    required this.enabled,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Pad(
          theme: theme,
          enabled: enabled,
          icon: Icons.touch_app_rounded,
          label: 'Hold',
          caption: 'word + its end',
          filled: false,
          onDown: onHoldStart,
          onUp: onHoldEnd,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Pad(
          theme: theme,
          enabled: enabled,
          icon: Icons.keyboard_double_arrow_right_rounded,
          label: 'Next word',
          caption: 'flows on',
          filled: true,
          onDown: onNext,
        ),
      ),
    ],
  );
}

class _Pad extends StatefulWidget {
  final LrcTheme theme;
  final bool enabled;
  final IconData icon;
  final String label;
  final String caption;
  final bool filled;
  final VoidCallback onDown;
  final VoidCallback? onUp;

  const _Pad({
    required this.theme,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.caption,
    required this.filled,
    required this.onDown,
    this.onUp,
  });

  @override
  State<_Pad> createState() => _PadState();
}

class _PadState extends State<_Pad> {
  int? _pointer;

  bool get _down => _pointer != null;

  void _release(PointerEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _pointer = null);
    widget.onUp?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final on = widget.enabled;
    final base = on ? theme.primary : theme.textMuted;
    final bg = widget.filled
        ? base.withValues(alpha: _down ? 1 : (on ? 0.85 : 0.15))
        : base.withValues(alpha: _down ? 0.35 : 0.12);
    final fg = widget.filled && on ? Colors.white : base;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (!widget.enabled || _down) return;
        widget.onDown();
        setState(() => _pointer = e.pointer);
        HapticFeedback.lightImpact();
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.fast,
        curve: Motion.standard,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: base.withValues(alpha: on ? 0.5 : 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: fg, size: 22),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.caption,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
