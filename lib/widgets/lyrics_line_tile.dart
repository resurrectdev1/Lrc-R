import 'package:flutter/material.dart';
import '../models/lrc_session.dart';
import '../theme/lrc_theme.dart';

class LyricsLineTile extends StatefulWidget {
  final LrcLine      line;
  final int          index;
  final bool         isNext;
  final LrcTheme     theme;
  final LrcSession   session;
  final VoidCallback             onTap;
  final VoidCallback             onUntag;
  final ValueChanged<String>     onEdit;
  final VoidCallback             onDelete;

  const LyricsLineTile({
    super.key,
    required this.line,    required this.index,
    required this.isNext,  required this.theme,
    required this.session, required this.onTap,
    required this.onUntag, required this.onEdit,
    required this.onDelete,
  });

  @override
  State<LyricsLineTile> createState() => _LyricsLineTileState();
}

class _LyricsLineTileState extends State<LyricsLineTile>
with SingleTickerProviderStateMixin {
  bool _editing = false;
  bool _shakeError = false;
  late TextEditingController _ctrl;
  late AnimationController  _shakeCtrl;
  late Animation<double>     _shakeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.line.text);
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end:  6), weight: 1),
      TweenSequenceItem(tween: Tween(begin:  6, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end:  6), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  6, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end:  0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(LyricsLineTile old) {
    super.didUpdateWidget(old);
    if (!_editing && old.line.text != widget.line.text) {
      _ctrl.text = widget.line.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _commitEdit() {
    if (_ctrl.text.trim().isEmpty) {
      setState(() => _shakeError = true);
      _shakeCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _shakeError = false);
      });
        return;
    }
    setState(() => _editing = false);
    widget.onEdit(_ctrl.text.trim());
  }

  String _compactTs(Duration d) {
    final m  = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  @override
  Widget build(BuildContext context) {
    final theme  = widget.theme;
    final isNext = widget.isNext;
    final tagged = widget.line.isTagged;

    Color borderColor;
    Color bgColor;
    if (isNext) {
      borderColor = theme.primary.withValues(alpha: 0.5);
      bgColor     = theme.primary.withValues(alpha: 0.07);
    } else if (tagged) {
      borderColor = theme.primary.withValues(alpha: 0.3);
      bgColor     = theme.primary.withValues(alpha: 0.05);
    } else {
      borderColor = theme.textMuted.withValues(alpha: 0.15);
      bgColor     = theme.surface;
    }

    if (_shakeError) borderColor = LrcTheme.errorRed;

    Widget tile = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:   const EdgeInsets.symmetric(vertical: 4),
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ReorderableDragStartListener(
                index: widget.index,
                child: Icon(
                  Icons.drag_handle_rounded,
                  size:  18,
                  color: theme.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ),

            SizedBox(
              width: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNext)
                    Icon(Icons.arrow_right_rounded, color: theme.primary, size: 22)
                    else if (tagged)
                      Icon(Icons.check_circle_rounded, color: theme.primary, size: 16)
                      else
                        Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                            fontSize:   11,
                            color:      theme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (tagged)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _compactTs(widget.line.timestamp!),
                              style: TextStyle(
                                fontSize:      7.5,
                                color:         theme.primary,
                                fontWeight:    FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: _editing
              ? AnimatedBuilder(
                animation: _shakeAnim,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus:  true,
                  style:      TextStyle(fontSize: 14, color: theme.textPrimary),
                  decoration: InputDecoration(
                    isDense:        true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   BorderSide(
                        color: _shakeError ? LrcTheme.errorRed : theme.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   BorderSide(
                        color: _shakeError ? LrcTheme.errorRed : theme.primary,
                        width: 1.5,
                      ),
                    ),
                    errorText:  _shakeError ? 'Text cannot be empty' : null,
                    errorStyle: const TextStyle(fontSize: 10),
                  ),
                  onSubmitted: (_) => _commitEdit(),
                ),
              )
              : Text(
                widget.line.text,
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
                  color:      isNext ? theme.textPrimary : theme.textSecondary,
                  height:     1.4,
                ),
              ),
            ),

            const SizedBox(width: 8),

            if (_editing) ...[
              GestureDetector(
                onTap: _commitEdit,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color:        theme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_rounded, color: theme.primary, size: 16),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _editing    = false;
                  _shakeError = false;
                  _ctrl.text  = widget.line.text;
                }),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color:        LrcTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded, color: LrcTheme.errorRed, size: 16),
                ),
              ),
            ] else ...[
              _MiniBtn(
                icon:  Icons.edit_rounded,
                color: theme.textMuted,
                onTap: () => setState(() => _editing = true),
              ),
              const SizedBox(width: 4),
              if (tagged) ...[
                _MiniBtn(
                  icon:  Icons.timer_off_rounded,
                  color: LrcTheme.errorRed,
                  onTap: widget.onUntag,
                ),
                const SizedBox(width: 4),
              ],
              _MiniBtn(
                icon:  Icons.delete_outline_rounded,
                color: LrcTheme.errorRed.withValues(alpha: 0.7),
                onTap: widget.onDelete,
              ),
            ],
          ],
        ),
      ),
    );

    if (_editing) return tile;
    return tile;
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 14),
    ),
  );
}
