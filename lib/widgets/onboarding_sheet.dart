import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/lrc_settings.dart';
import '../theme/lrc_theme.dart';

const _kOnboardingDone = 'lrc_onboarding_done';
Future<bool> shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  final done  = prefs.getBool(_kOnboardingDone) ?? false;
  if (!done) await prefs.setBool(_kOnboardingDone, true);
  return !done;
}

class LrcOnboardingSheet extends StatefulWidget {
  const LrcOnboardingSheet({super.key});

  @override
  State<LrcOnboardingSheet> createState() => _LrcOnboardingSheetState();
}

class _LrcOnboardingSheetState extends State<LrcOnboardingSheet> {
  int _page = 0;

  static const _steps = [
    _OnboardStep(
      icon:      Icons.lyrics_rounded,
      iconColor: LrcTheme.accentBlue,
      title:     'Welcome to Lrc-R 🎧',
      body:      'A free, open-source synced-lyrics editor. '
    'Tap along to your music and export a perfect .lrc file '
    'everything is processed locally on your device, no cloud needed.',
    kind:      _StepKind.intro,
    ),
    _OnboardStep(
      icon:      Icons.audiotrack_rounded,
      iconColor: LrcTheme.accentPurple,
      title:     'Load Your Audio',
      body:      'Pick any MP3, FLAC, M4A, WAV or OGG file from your device. '
    'The built-in player lets you scrub, skip ±5 s, and adjust '
    'playback speed to make tagging easier.',
    kind:      _StepKind.audio,
    ),
    _OnboardStep(
      icon:      Icons.text_snippet_rounded,
      iconColor: LrcTheme.accentTeal,
      title:     'Add Your Lyrics',
      body:      'Paste plain-text lyrics, open an existing .lrc or .txt file, '
    'or type each line directly. Lines can be reordered by dragging, '
    'edited inline, or deleted at any time.',
    kind:      _StepKind.lyrics,
    ),
    _OnboardStep(
      icon:      Icons.touch_app_rounded,
      iconColor: LrcTheme.accentGreen,
      title:     'Tap to Tag',
      body:      'Hit the TAG button as each lyric line starts playing. '
    'Lrc-R stamps it with the exact playback position. '
    'Made a mistake? Undo the last action, untag a single line, '
    'or reset all timestamps and start over.',
    kind:      _StepKind.tag,
    ),
    _OnboardStep(
      icon:      Icons.download_rounded,
      iconColor: LrcTheme.accentBlue,
      title:     'Export & Share',
      body:      'Once all lines are tagged, copy the LRC to your clipboard '
    'or save the .lrc file directly to your desired path in your device. '
    'Drop it into any music player that supports synced lyrics and enjoy!',
    kind:      _StepKind.export,
    ),
  ];

  void _advance() {
    HapticFeedback.selectionClick();
    if (_page < _steps.length - 1) {
      setState(() => _page++);
    } else {
      Navigator.pop(context);
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    final theme     = context.watch<LrcSettings>().theme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final step      = _steps[_page];
    final isLast    = _page == _steps.length - 1;
    final isFirst   = _page == 0;

    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        theme.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
            child: Container(
              key:    ValueKey('icon_$_page'),
              width:  96, height: 96,
              decoration: BoxDecoration(
                color:        step.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(step.icon, color: step.iconColor, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              step.title,
              key:       ValueKey('title_$_page'),
              style:     TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      theme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              step.body,
              key:       ValueKey('body_$_page'),
              style:     TextStyle(
                fontSize: 14,
                color:    theme.textSecondary,
                height:   1.65,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) => AnimatedContainer(
              duration:  const Duration(milliseconds: 250),
              margin:    const EdgeInsets.symmetric(horizontal: 3),
              width:     i == _page ? 18 : 6,
              height:    6,
              decoration: BoxDecoration(
                color:        i == _page
                ? theme.primary
                : theme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!isFirst) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _back,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textSecondary,
                        side:        BorderSide(color: theme.textMuted.withValues(alpha: 0.4)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: isFirst ? 1 : 2,
                child: FilledButton(
                  onPressed: _advance,
                  style: FilledButton.styleFrom(
                    backgroundColor: isLast
                    ? LrcTheme.accentBlue
                    : theme.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast  ? 'Start Making LRCs 🎧' :
                    isFirst ? 'Get Started'           :
                    'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

enum _StepKind { intro, audio, lyrics, tag, export }

class _OnboardStep {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    body;
  final _StepKind kind;

  const _OnboardStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.kind,
  });
}
