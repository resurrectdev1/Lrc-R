import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme/lrc_theme.dart';

class LrcSettingsSheet extends StatefulWidget {
  const LrcSettingsSheet({super.key});

  @override
  State<LrcSettingsSheet> createState() => _LrcSettingsSheetState();
}

class _LrcSettingsSheetState extends State<LrcSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final liveSettings = context.watch<LrcSettings>();
    final theme        = liveSettings.theme;
    final navBar       = MediaQuery.of(context).viewPadding.bottom;
    final kb           = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navBar + kb),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color:        theme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      theme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel('THEME', theme),
              const SizedBox(height: 10),
              ...LrcThemeMode.values.map((mode) {
                final labels = {
                  LrcThemeMode.darkSlate:    ('Dark Blue',     'Default dark theme'),
                  LrcThemeMode.amoledBlack:  ('AMOLED Black',  'Pure black for OLED screens'),
                  LrcThemeMode.materialYou:  ('Material You',  'Follows your wallpaper colours'),
                  LrcThemeMode.whiteMinimal: ('White Minimal', 'Clean light theme'),
                };
                final (label, sub) = labels[mode]!;
                final isActive = liveSettings.themeMode == mode;
                return GestureDetector(
                  onTap: () => liveSettings.setThemeMode(mode),
                  child: Container(
                    margin:     const EdgeInsets.only(bottom: 8),
                    padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                      ? theme.primary.withValues(alpha: 0.1)
                      : theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                        ? theme.primary.withValues(alpha: 0.5)
                        : theme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                                color:      isActive ? theme.primary : theme.textPrimary,
                              )),
                              Text(sub, style: TextStyle(fontSize: 11, color: theme.textMuted)),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded, color: theme.primary, size: 18),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
              _SectionLabel('SESSION', theme),
              const SizedBox(height: 10),
              _SettingsToggle(
                icon:     Icons.screen_lock_portrait_rounded,
                label:    'Keep Screen On',
                sublabel: 'Prevent sleep while tagging lyrics',
                value:    liveSettings.keepScreenOn,
                theme:    theme,
                onChanged: (v) async {
                  await liveSettings.setKeepScreenOn(v);
                  await WakelockPlus.toggle(enable: v);
                  HapticFeedback.selectionClick();
                },
              ),

              const SizedBox(height: 20),
              _SectionLabel('EXPORT', theme),
              const SizedBox(height: 10),
              _SettingsToggle(
                icon:     Icons.label_off_rounded,
                label:    'Minimal Metadata',
                sublabel: 'Export only synced lyrics • no [ti]/[ar]/[al]/[length]/[by] tags',
                value:    liveSettings.minimalMetadata,
                theme:    theme,
                onChanged: (v) async {
                  await liveSettings.setMinimalMetadata(v);
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding:    const EdgeInsets.fromLTRB(14, 12, 14, 16),
                decoration: BoxDecoration(
                  color:        theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color:        LrcTheme.accentTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.tune_rounded,
                                            color: LrcTheme.accentTeal, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Timestamp Offset', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              )),
                              Text(
                                'Shift all timestamps on export to compensate for playback latency',
                                style: TextStyle(fontSize: 11, color: theme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:        LrcTheme.accentTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border:       Border.all(color: LrcTheme.accentTeal.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${liveSettings.timestampOffsetMs > 0 ? '+' : ''}${liveSettings.timestampOffsetMs} ms',
                            style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: LrcTheme.accentTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight:        3,
                        thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:       const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor:   LrcTheme.accentTeal,
                        inactiveTrackColor: theme.surfaceHigh,
                        thumbColor:         LrcTheme.accentTeal,
                        overlayColor:       LrcTheme.accentTeal.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value:    liveSettings.timestampOffsetMs.toDouble(),
                        min:      -500,
                        max:      500,
                        divisions: 40,
                        onChanged: (v) {
                          liveSettings.setTimestampOffset(v.round());
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('−500 ms', style: TextStyle(fontSize: 10, color: theme.textMuted)),
                          Text('0',       style: TextStyle(fontSize: 10, color: theme.textMuted)),
                          Text('+500 ms', style: TextStyle(fontSize: 10, color: theme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Negative = lyrics appear earlier  •  Positive = lyrics appear later',
                style: TextStyle(fontSize: 10, color: theme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String   label;
  final LrcTheme theme;
  const _SectionLabel(this.label, this.theme);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: theme.textMuted, letterSpacing: 1.0,
    ),
  );
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sublabel;
  final bool     value;
  final LrcTheme theme;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,     required this.label,
    required this.sublabel, required this.value,
    required this.theme,    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        theme.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:        theme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: theme.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                  Text(sublabel, style: TextStyle(fontSize: 11, color: theme.textMuted)),
              ],
            ),
          ),
          Switch(
            value:           value,
            onChanged:       onChanged,
            activeThumbColor: theme.primary,
            activeTrackColor: theme.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
