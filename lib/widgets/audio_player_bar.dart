import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lrc_session.dart';
import '../theme/lrc_theme.dart';

class AudioPlayerBar extends StatelessWidget {
  final LrcSession   session;
  final LrcTheme     theme;
  final VoidCallback onChangeSong;

  const AudioPlayerBar({
    super.key,
    required this.session,
    required this.theme,
    required this.onChangeSong,
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final pos         = session.audioPosition;
    final dur         = session.audioDuration;
    final progress    = dur.inMilliseconds == 0
    ? 0.0
    : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color:        theme.surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.audioName ?? 'Unknown track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      theme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onChangeSong,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        theme.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: theme.textMuted.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 12, color: theme.textSecondary),
                      const SizedBox(width: 4),
                      Text('Change', style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      theme.textSecondary,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          SliderTheme(
            data: SliderThemeData(
              trackHeight:        3,
              thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape:       const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor:   theme.primary,
              inactiveTrackColor: theme.surfaceHigh,
              thumbColor:         theme.primary,
              overlayColor:       theme.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value:     progress,
              onChanged: (v) => session.seek(
                Duration(milliseconds: (v * dur.inMilliseconds).round())),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(session.formatDuration(pos),
                style: TextStyle(fontSize: 10, color: theme.textMuted)),
                Text(session.formatDuration(dur),
                style: TextStyle(fontSize: 10, color: theme.textMuted)),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CtrlBtn(
                icon:  Icons.replay_5_rounded,
                color: theme.textSecondary,
                size:  20,
                onTap: session.skipBack5,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: session.playPause,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color:        theme.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    session.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CtrlBtn(
                icon:  Icons.forward_5_rounded,
                color: theme.textSecondary,
                size:  20,
                onTap: session.skipForward5,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _speeds.map((speed) {
                final active = session.playbackSpeed == speed;
                final label  = speed == 1.0 ? '1×' : '$speed×';
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () {
                    session.setSpeed(speed);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                      ? theme.primary.withValues(alpha: 0.18)
                      : theme.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                        ? theme.primary.withValues(alpha: 0.6)
                        : theme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      active ? theme.primary : theme.textMuted,
                      ),
                    ),
                  ),
                ),
              );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final double       size;
  final VoidCallback onTap;

  const _CtrlBtn({required this.icon, required this.color,
    required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size),
    ),
  );
}
