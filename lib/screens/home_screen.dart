import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/lrc_session.dart';
import '../theme/lrc_theme.dart';
import '../widgets/audio_player_bar.dart';
import '../widgets/lyrics_line_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/onboarding_sheet.dart';

class LrcHomeScreen extends StatefulWidget {
  const LrcHomeScreen({super.key});
  @override
  State<LrcHomeScreen> createState() => _LrcHomeScreenState();
}

class _LrcHomeScreenState extends State<LrcHomeScreen>
with WidgetsBindingObserver {

  final ScrollController _lyricsScroll = ScrollController();
  late ConfettiController _confettiCtrl;
  bool _wasComplete = false;
  String _appVersion = '';
  final Map<int, GlobalKey> _tileKeys  = {};
  int                        _lastLineCount = -1;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _maybeShowOnboarding();
        _offerDraftRestore();
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiCtrl.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<LrcSession>();
    final isComplete = session.totalLines > 0 &&
    session.tagIndex >= session.totalLines;
    if (isComplete && !_wasComplete) {
      _wasComplete = true;
      _confettiCtrl.play();
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 120), () {
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 120), () {
          HapticFeedback.mediumImpact();
        });
      });
    }
    if (!isComplete) _wasComplete = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = context.read<LrcSession>();
    switch (state) {
      case AppLifecycleState.paused:
        session.saveDraft();
      case AppLifecycleState.resumed:
        final keepOn = context.read<LrcSettings>().keepScreenOn;
        if (keepOn) WakelockPlus.enable();
      default:
        break;
    }
  }

  Future<void> _maybeShowOnboarding() async {
    if (!mounted) return;
    if (!await shouldShowOnboarding()) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      isDismissible:      false,
      enableDrag:         false,
      useSafeArea:        true,
      builder: (_) => const LrcOnboardingSheet(),
    );
  }

  Future<void> _offerDraftRestore() async {
    if (!mounted) return;
    final session = context.read<LrcSession>();
    if (session.hasLyrics) return;
    final hasDraft = await session.hasDraft();
    if (!hasDraft || !mounted) return;

    final theme = context.read<LrcSettings>().theme;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Restore session?',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A draft from your last session was found. '
        'Would you like to restore it?\n\n'
        'Note: you will need to re-load the audio file.',
        style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Discard', style: TextStyle(color: theme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    ).then((restore) async {
      if (restore == true) {
        await session.loadDraft();
        if (mounted) {
          ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Session restored — please re-load the audio file'));
        }
      } else {
        await session.discardDraft();
      }
    });
  }

  GlobalKey _keyFor(int index, int currentLineCount) {
    if (currentLineCount != _lastLineCount) {
      _tileKeys.clear();
      _lastLineCount = currentLineCount;
    }
    return _tileKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToTagIndex(int tagIndex, int totalLines) {
    if (!_lyricsScroll.hasClients) return;
    final lookahead = (tagIndex + 1).clamp(0, totalLines - 1);
    final key = _tileKeys[lookahead];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration:  const Duration(milliseconds: 250),
      curve:     Curves.easeOut,
      alignment: 0.5,
    );
  }

  Future<void> _pickAudio(LrcSession session) async {
    final result = await FilePicker.platform.pickFiles(
      type:          FileType.audio,
      allowMultiple: false,
      dialogTitle:   'Choose an audio file',
    );
    if (result == null || result.files.single.path == null) return;
    await session.unloadAudio();
    await session.loadAudio(result.files.single.path!, result.files.single.name);
    if (mounted) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _pickLyrics(LrcSession session) async {
    if (!await _confirmOverwrite(session)) return;
    final result = await FilePicker.platform.pickFiles(
      type:              FileType.custom,
      allowedExtensions: ['txt', 'lrc'],
      allowMultiple:     false,
      dialogTitle:       'Choose a lyrics file (.txt or .lrc)',
    );
    if (result == null || result.files.single.path == null) return;
    final raw = await File(result.files.single.path!).readAsString();
    await _loadRawLyrics(session, raw);
    if (mounted) HapticFeedback.lightImpact();
  }

  Future<bool> _confirmOverwrite(LrcSession session) async {
    if (session.taggedCount == 0) return true;
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<LrcSettings>().theme;
        return AlertDialog(
          title: Text(
            'Replace lyrics?',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You have ${session.taggedCount} tagged line(s). '
          'Loading new lyrics will clear all timestamps.',
          style: TextStyle(color: theme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LrcTheme.errorRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _loadRawLyrics(LrcSession session, String raw) async {
    final conflict = session.setLyricsText(raw);
    if (conflict != null && mounted) {
      await _resolveMetadataConflict(session, conflict);
    }
  }

  Future<void> _resolveMetadataConflict(
    LrcSession session, MetadataConflict conflict) async {
      if (!mounted) return;
      final theme = context.read<LrcSettings>().theme;

      String row(String label, String val) =>
      val.isNotEmpty ? '$label: $val' : '';
      final fileInfo = [
        row('Title',  conflict.fileTitle),
        row('Artist', conflict.fileArtist),
        row('Album',  conflict.fileAlbum),
      ].where((s) => s.isNotEmpty).join('\n');
      final sessionInfo = [
        row('Title',  session.title),
        row('Artist', session.artist),
        row('Album',  session.album),
      ].where((s) => s.isNotEmpty).join('\n');

      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Metadata conflict',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The file contains metadata:',
                   style: TextStyle(fontSize: 12, color: theme.textMuted)),
                   const SizedBox(height: 4),
                   Text(fileInfo,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text('Current session metadata:',
                               style: TextStyle(fontSize: 12, color: theme.textMuted)),
                               const SizedBox(height: 4),
                               Text(sessionInfo,
                                    style: TextStyle(fontSize: 13, color: theme.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep mine', style: TextStyle(color: theme.textMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use file'),
            ),
          ],
        ),
      );
      session.applyMetadataConflict(conflict, replace: replace == true);
    }

    void _showPasteLyricsSheet(LrcSession session, LrcTheme theme) {
      showModalBottomSheet(
        context:            context,
        backgroundColor:    Colors.transparent,
        isScrollControlled: true,
        useSafeArea:        true,
        builder: (ctx) => _PasteLyricsSheet(
          theme:    theme,
          onSubmit: (raw, {String title = '', String artist = '', String album = ''}) async {
            if (!await _confirmOverwrite(session)) return;
            await _loadRawLyrics(session, raw);
            if (title.isNotEmpty  && session.title.isEmpty)  session.setTitle(title);
            if (artist.isNotEmpty && session.artist.isEmpty) session.setArtist(artist);
            if (album.isNotEmpty  && session.album.isEmpty)  session.setAlbum(album);
            HapticFeedback.lightImpact();
          },
        ),
      );
    }

    Future<void> _copyToClipboard(LrcSession session) async {
      final settings = context.read<LrcSettings>();
      await Clipboard.setData(ClipboardData(
        text: session.buildLrc(
          offsetMs: settings.timestampOffsetMs,
          minimal:  settings.minimalMetadata,
        ),
      ));
      await session.discardDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack('LRC copied to clipboard ✓'));
      }
    }

    Future<void> _shareLrc(LrcSession session) async {
      final settings = context.read<LrcSettings>();
      final lrc = session.buildLrc(
        offsetMs: settings.timestampOffsetMs,
        minimal:  settings.minimalMetadata,
      );
      final baseName = session.audioName != null
      ? session.audioName!.replaceAll(RegExp(r'\.[^.]+$'), '')
      : 'lyrics';
      final fileName = '$baseName.lrc';

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(lrc);

      final result = await Share.shareXFiles([XFile(file.path)], subject: fileName);
      if (result.status == ShareResultStatus.success && mounted) {
        await session.discardDraft();
      }
    }

    void _showExportOptionsSheet(LrcSession session, LrcTheme theme) {
      showModalBottomSheet(
        context:            context,
        backgroundColor:    Colors.transparent,
        isScrollControlled: true,
        useSafeArea:        true,
        builder: (ctx) {
          final navBar = MediaQuery.of(ctx).viewPadding.bottom;
          return Container(
            decoration: BoxDecoration(
              color:        theme.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + navBar),
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
                Text('Export LRC', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Choose how you\'d like to export your synced lyrics',
                       style: TextStyle(fontSize: 13, color: theme.textSecondary)),
                       const SizedBox(height: 20),
                       _ExportOptionTile(
                         icon:     Icons.copy_rounded,
                         color:    LrcTheme.accentBlue,
                         label:    'Copy to Clipboard',
                         sublabel: 'Paste it anywhere as plain text',
                         theme:    theme,
                         onTap: () {
                           Navigator.pop(ctx);
                           _copyToClipboard(session);
                         },
                       ),
                       const SizedBox(height: 10),
                       _ExportOptionTile(
                         icon:     Icons.ios_share_rounded,
                         color:    LrcTheme.accentTeal,
                         label:    'Share',
                         sublabel: 'Send the .lrc file to another app',
                         theme:    theme,
                         onTap: () {
                           Navigator.pop(ctx);
                           _shareLrc(session);
                         },
                       ),
              ],
            ),
          );
        },
      );
    }

    Future<void> _saveLrc(LrcSession session) async {
      final settings = context.read<LrcSettings>();
      final lrc = session.buildLrc(
        offsetMs: settings.timestampOffsetMs,
        minimal:  settings.minimalMetadata,
      );
      final baseName = session.audioName != null
      ? session.audioName!.replaceAll(RegExp(r'\.[^.]+$'), '')
      : 'lyrics';
      final fileName = '$baseName.lrc';

      try {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle:   'Save LRC file',
          fileName:      fileName,
          type:          FileType.custom,
          allowedExtensions: ['lrc'],
          bytes:         Uint8List.fromList(lrc.codeUnits),
        );

        if (savePath == null) return;
        final file = File(savePath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsString(lrc);
        }

        if (mounted) {
          ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Saved as $fileName ✓'));
          await session.discardDraft();
        }
      } catch (_) {
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(lrc);
        await Share.shareXFiles([XFile(file.path)], subject: fileName);
      }
    }

    SnackBar _snack(String msg, {bool error = false}) => SnackBar(
      content:         Text(msg),
      backgroundColor: error ? LrcTheme.errorRed : LrcTheme.accentGreen,
      behavior:        SnackBarBehavior.floating,
      duration:        const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    void _showAboutSheet(BuildContext ctx, LrcTheme theme) {
      final navBar = MediaQuery.of(ctx).viewPadding.bottom;
      showModalBottomSheet(
        context:            ctx,
        backgroundColor:    theme.surfaceHigh,
        isScrollControlled: true,
        useSafeArea:        true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navBar),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 52, height: 52, fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lrc-R', style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        color: theme.textPrimary, letterSpacing: 1)),
                         Text('v${_appVersion.isEmpty ? '...' : _appVersion} • Open Source',
                              style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Lrc-R is a minimalistic synced-lyrics editor designed to keep your music '
              'experience complete. Tag any song entirely on your device, worry free. '
              'Built with love as a free, open-source tool. ',
              style: TextStyle(fontSize: 13, color: theme.textSecondary, height: 1.6),
              ),
              const SizedBox(height: 24),
              Text('LINKS', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: theme.textMuted, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                _AboutLinkTile(
                  icon:      Icons.code_rounded,
                  iconColor: theme.textPrimary,
                  label:     'GitHub',
                  sublabel:  'Source code & contributions',
                  url:       'https://github.com/resurrectdev1/lrc-r',
                  theme:     theme,
                ),
                const SizedBox(height: 10),
                _AboutLinkTile(
                  icon:      Icons.coffee_rounded,
                  iconColor: const Color(0xFFFFDD57),
                  label:     'Buy Me a Coffee',
                  sublabel:  'Support development',
                  url:       'https://buymeacoffee.com/resurrect',
                  theme:     theme,
                ),
                const SizedBox(height: 24),
                Text(
                  'Made with 🎧 • all data stays on your device.',
                  style:     TextStyle(fontSize: 10, color: theme.textMuted),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final settings = context.watch<LrcSettings>();
      final theme    = settings.theme;
      final session  = context.watch<LrcSession>();

      return Scaffold(
        backgroundColor:         theme.bg,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: theme.bg,
          elevation:       0,
          centerTitle:     true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: IconButton(
              icon:    Icon(Icons.info_outline_rounded, color: theme.textSecondary, size: 20),
              onPressed: () => _showAboutSheet(context, theme),
              tooltip: 'About',
            ),
          ),
          title: Text(
            'L R C - R',
            style: TextStyle(
              color:         theme.textSecondary,
              fontSize:      13,
              fontWeight:    FontWeight.w400,
              letterSpacing: 6,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(Icons.settings_outlined, color: theme.textSecondary, size: 20),
                onPressed: () => showModalBottomSheet(
                  context:            context,
                  backgroundColor:    Colors.transparent,
                  isScrollControlled: true,
                  useSafeArea:        true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  builder: (_) => const LrcSettingsSheet(),
                ),
                tooltip: 'Settings',
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!session.hasAudio || !session.hasLyrics)
                  Expanded(child: _buildSetupCards(session, theme)),
                  if (session.hasLyrics && session.hasAudio)
                    Expanded(child: _buildLyricsList(session, theme))
                    else if (session.hasLyrics)
                      Flexible(child: _buildLyricsList(session, theme)),
                      if (session.hasAudio && session.hasLyrics)
                        AudioPlayerBar(
                          session:      session,
                          theme:        theme,
                          onChangeSong: () => _pickAudio(session),
                        ),
                   if (session.hasAudio && session.hasLyrics)
                     _buildActionBar(session, theme),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles:   28,
                gravity:             0.15,
                emissionFrequency:   0.04,
                maxBlastForce:       18,
                minBlastForce:       6,
                colors: [
                  theme.primary,
                  LrcTheme.accentGreen,
                  LrcTheme.accentPurple,
                  LrcTheme.accentTeal,
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildSetupCards(LrcSession session, LrcTheme theme) {
      final accent = theme.primary;
      Widget doneBanner = Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_rounded, color: accent, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.audioName ?? 'Audio ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: theme.textPrimary),
                  ),
                  Text('Step 1 complete',
                       style: TextStyle(fontSize: 11, color: theme.textMuted)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _pickAudio(session),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 12, color: accent),
                    const SizedBox(width: 4),
                    Text('Change', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      Widget stepContent({
        required IconData icon,
        required String   title,
        required String   subtitle,
        required String   formats,
        required Widget   buttons,
      }) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color:        accent.withValues(alpha: 0.2),
                    blurRadius:   40,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: accent, size: 40),
            ),
            const SizedBox(height: 24),
            Text(title,
                 style: TextStyle(
                   fontSize: 22, fontWeight: FontWeight.w800,
                   color: theme.textPrimary)),
                   const SizedBox(height: 8),
                   Text(subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14, color: theme.textSecondary, height: 1.5)),
                      const SizedBox(height: 6),
                      Text(formats,
                           style: TextStyle(
                             fontSize: 11, fontWeight: FontWeight.w600,
                             color: accent.withValues(alpha: 0.6),
                             letterSpacing: 0.6)),
                      const SizedBox(height: 36),
                      buttons,
          ],
        );
      }

      if (!session.hasAudio) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              stepContent(
                icon:     Icons.audiotrack_rounded,
                title:    'Load Audio',
                subtitle: 'Pick the song you want to sync lyrics to',
                formats:  'MP3 · WAV · FLAC · AAC · OGG',
                  buttons:  SizedBox(
                    width:  double.infinity,
                    height: 54,
                    child:  FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      ),
                      icon:     const Icon(Icons.folder_open_rounded, size: 20),
                      label:    const Text('Choose File',
                                           style: TextStyle(
                                             fontSize: 15, fontWeight: FontWeight.w700)),
                                              onPressed: () => _pickAudio(session),
                    ),
                  ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          doneBanner,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  stepContent(
                    icon:     Icons.lyrics_rounded,
                    title:    'Load Lyrics',
                    subtitle: 'Paste your lyrics or open an existing file',
                    formats:  'TXT · LRC',
                      buttons:  Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 54,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                ),
                                icon:     const Icon(Icons.content_paste_rounded,
                                                     size: 18),
                                                     label:    const Text('Paste',
                                                                          style: TextStyle(
                                                                            fontSize: 15, fontWeight: FontWeight.w700)),
                                                       onPressed: () =>
                                                       _showPasteLyricsSheet(session, theme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                    side: BorderSide(
                                      color: accent.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                ),
                                icon:     const Icon(Icons.folder_open_rounded,
                                                     size: 18),
                                                     label:    const Text('File',
                                                                          style: TextStyle(
                                                                            fontSize: 15, fontWeight: FontWeight.w700)),
                                                         onPressed: () => _pickLyrics(session),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildLyricsList(LrcSession session, LrcTheme theme) {
      if (session.lines.isEmpty) {
        return EmptyState(
          icon:  Icons.lyrics_rounded,
          color: LrcTheme.accentTeal,
          title: 'No lyrics yet',
          body:  'Paste or load a lyrics file to get started.',
          theme: theme,
        );
      }

      Widget footer = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                session.addLine(session.lines.length - 1);
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:       theme.textMuted.withValues(alpha: 0.2),
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: theme.textMuted),
                    const SizedBox(width: 6),
                    Text('Add line', style: TextStyle(
                      fontSize: 13, color: theme.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Remove all lyrics?', style: TextStyle(
                    color: theme.textPrimary, fontWeight: FontWeight.w700)),
                    content: Text('All lines and timestamps will be cleared.',
                                  style: TextStyle(color: theme.textSecondary)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: LrcTheme.errorRed),
                                      onPressed: () {
                                        if (session.isPlaying) session.playPause();
                                        session.clearLyrics();
                                        Navigator.pop(ctx);
                                        HapticFeedback.mediumImpact();
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:        LrcTheme.errorRed.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:       LrcTheme.errorRed.withValues(alpha: 0.2),
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                         size: 16, color: LrcTheme.errorRed.withValues(alpha: 0.7)),
                         const SizedBox(width: 6),
                         Text('Remove all lyrics', style: TextStyle(
                           fontSize: 13,
                           color:    LrcTheme.errorRed.withValues(alpha: 0.7),
                           fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

      final minimalMetadata = context.watch<LrcSettings>().minimalMetadata;

      return ReorderableListView.builder(
        scrollController: _lyricsScroll,
        padding:          const EdgeInsets.fromLTRB(16, 8, 16, 0),
        buildDefaultDragHandles: false,
        itemCount:    session.lines.length,
        header:       _MetadataSection(
          session: session,
          theme:   theme,
          minimal: minimalMetadata,
        ),
        footer:       footer,
        onReorder: (oldIndex, newIndex) {
          final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
          if (oldIndex < 0 || oldIndex >= session.lines.length) return;
          if (adjustedNew < 0 || adjustedNew >= session.lines.length) return;
          session.moveLine(oldIndex, adjustedNew);
          HapticFeedback.selectionClick();
        },
        itemBuilder: (ctx, i) {
          final line = session.lines[i];
          return LyricsLineTile(
            key:     _keyFor(i, session.lines.length),
            line:    line,
            index:   i,
            isNext:  i == session.tagIndex,
            theme:   theme,
            session: session,
            onTap:   () {
              session.setTagIndex(i);
              if (line.isTagged) session.seek(line.timestamp!);
            },
            onUntag: () => session.untag(i),
            onEdit:  (txt) => session.editLine(i, txt),
            onDelete: () => session.deleteLine(i),
          );
        },
      );
    }

    Widget _buildActionBar(LrcSession session, LrcTheme theme) {
      final navBar   = MediaQuery.of(context).viewPadding.bottom;
      final progress = session.totalLines == 0
      ? 0.0
      : session.taggedCount / session.totalLines;

      return Container(
        color:   theme.bg,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + navBar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           progress,
                      backgroundColor: theme.surfaceHigh,
                      valueColor:      AlwaysStoppedAnimation(theme.primary),
                      minHeight:       4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${session.taggedCount} / ${session.totalLines}',
                  style: TextStyle(
                    fontSize:   12,
                    color:      theme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      minimumSize:     const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon:  const Icon(Icons.timer_rounded, size: 20),
                    label: Text(
                      session.tagIndex < session.totalLines
                      ? 'Tag  Line ${session.tagIndex + 1}'
                    : 'All lines tagged ✓',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    onPressed: session.tagIndex < session.totalLines
                    ? () {
                      session.tagCurrentLine();
                      _scrollToTagIndex(session.tagIndex, session.totalLines);
                      HapticFeedback.mediumImpact();
                    }
                    : null,
                  ),
                ),
                const SizedBox(width: 10),
                _ActionIconButton(
                  icon:    Icons.undo_rounded,
                  color:   LrcTheme.accentPurple,
                  tooltip: 'Undo',
                  theme:   theme,
                  enabled: session.canUndo,
                  onTap: () {
                    session.undoLast();
                    HapticFeedback.lightImpact();
                  },
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon:    Icons.ios_share_rounded,
                  color:   LrcTheme.accentBlue,
                  tooltip: 'Copy or Share',
                  theme:   theme,
                  enabled: session.canExport,
                  onTap:   () => _showExportOptionsSheet(session, theme),
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon:    Icons.download_rounded,
                  color:   LrcTheme.accentTeal,
                  tooltip: 'Save LRC',
                  theme:   theme,
                  enabled: session.canExport,
                  onTap:   () => _saveLrc(session),
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon:    Icons.restart_alt_rounded,
                  color:   LrcTheme.errorRed,
                  tooltip: 'Reset all tags',
                  theme:   theme,
                  enabled: session.taggedCount > 0,
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Reset all timestamps?', style: TextStyle(
                        color: theme.textPrimary, fontWeight: FontWeight.w700)),
                        content: Text('All tagged timestamps will be cleared.',
                                      style: TextStyle(color: theme.textSecondary)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: LrcTheme.errorRed),
                                            onPressed: () {
                                              session.resetAllTags();
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text('Reset'),
                                        ),
                                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
}

class _PasteLyricsSheet extends StatefulWidget {
  final LrcTheme theme;
  final Future<void> Function(String raw, {String title, String artist, String album}) onSubmit;

  const _PasteLyricsSheet({required this.theme, required this.onSubmit});

  @override
  State<_PasteLyricsSheet> createState() => _PasteLyricsSheetState();
}

class _PasteLyricsSheetState extends State<_PasteLyricsSheet> {
  int _step = 0;

  late final TextEditingController _lyricsCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;

  @override
  void initState() {
    super.initState();
    _lyricsCtrl = TextEditingController();
    _titleCtrl  = TextEditingController();
    _artistCtrl = TextEditingController();
    _albumCtrl  = TextEditingController();
  }

  @override
  void dispose() {
    _lyricsCtrl.dispose();
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (_lyricsCtrl.text.trim().isEmpty) return;
    if (_hasEmbeddedMetadata(_lyricsCtrl.text)) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         const Text('Detected embedded metadata — using it automatically'),
        backgroundColor: LrcTheme.accentTeal,
        behavior:        SnackBarBehavior.floating,
        duration:        const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _submit();
      return;
    }
    setState(() => _step = 1);
  }

  bool _hasEmbeddedMetadata(String raw) {
    final metaPattern = RegExp(r'^\[(ti|ar|al):(.*)\]$', caseSensitive: false);
    for (final rawLine in raw.split('\n')) {
      final line  = rawLine.trim();
      final match = metaPattern.firstMatch(line);
      if (match != null && match.group(2)!.trim().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _submit() async {
    final raw = _lyricsCtrl.text;
    Navigator.pop(context);
    await widget.onSubmit(
      raw,
      title:  _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
      album:  _albumCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme  = widget.theme;
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final kb     = MediaQuery.of(context).viewInsets.bottom;
    final maxH   = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve:  Curves.easeOut,
          switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end:   Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _step == 0
            ? _LyricsStep(
              key:        const ValueKey('step_lyrics'),
              theme:      theme,
              ctrl:       _lyricsCtrl,
              navBar:     navBar,
              kb:         kb,
              onAdvance:  _advance,
            )
            : _MetaStep(
              key:        const ValueKey('step_meta'),
              theme:      theme,
              titleCtrl:  _titleCtrl,
              artistCtrl: _artistCtrl,
              albumCtrl:  _albumCtrl,
              navBar:     navBar,
              kb:         kb,
              onBack:     () => setState(() => _step = 0),
              onSubmit:   _submit,
            ),
      ),
    );
  }
}

class _LyricsStep extends StatelessWidget {
  final LrcTheme               theme;
  final TextEditingController  ctrl;
  final double                 navBar;
  final double                 kb;
  final VoidCallback           onAdvance;

  const _LyricsStep({
    super.key,
    required this.theme,
    required this.ctrl,
    required this.navBar,
    required this.kb,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paste Lyrics', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: theme.textPrimary)),
                      const SizedBox(height: 2),
                      Text('One lyric line per line. Blank lines are ignored.',
                           style: TextStyle(fontSize: 13, color: theme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: theme.primary.withValues(alpha: 0.3)),
                ),
                child: Text('1 of 2', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: theme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: TextField(
                controller: ctrl,
                maxLines:   null,
                minLines:   6,
                autofocus:  true,
                style: TextStyle(color: theme.textPrimary, fontSize: 14, height: 1.6),
                decoration: const InputDecoration(hintText: 'Paste your lyrics here…'),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + (kb > 0 ? kb : navBar)),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onAdvance,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Next', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaStep extends StatelessWidget {
  final LrcTheme               theme;
  final TextEditingController  titleCtrl;
  final TextEditingController  artistCtrl;
  final TextEditingController  albumCtrl;
  final double                 navBar;
  final double                 kb;
  final VoidCallback           onBack;
  final VoidCallback           onSubmit;

  const _MetaStep({
    super.key,
    required this.theme,
    required this.titleCtrl,
    required this.artistCtrl,
    required this.albumCtrl,
    required this.navBar,
    required this.kb,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final minimalOn = context.watch<LrcSettings>().minimalMetadata;
    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Metadata', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: theme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          minimalOn
                          ? 'Optional • Minimal Metadata is ON, so these won\'t be exported'
                        : 'Optional • embedded as [ti:] [ar:] [al:] tags',
                        style: TextStyle(fontSize: 13, color: theme.textSecondary),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: theme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text('2 of 2', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: theme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _MetaField(
              controller: titleCtrl,
              label: 'Song Title',
              tag:   '[ti:]',
              icon:  Icons.music_note_rounded,
              theme: theme,
            ),
            const SizedBox(height: 10),
            _MetaField(
              controller: artistCtrl,
              label: 'Artist Name',
              tag:   '[ar:]',
              icon:  Icons.person_rounded,
              theme: theme,
            ),
            const SizedBox(height: 10),
            _MetaField(
              controller: albumCtrl,
              label: 'Album Name',
              tag:   '[al:]',
              icon:  Icons.album_rounded,
              theme: theme,
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 50, height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side:  BorderSide(color: theme.textMuted.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onBack,
                    child: Icon(Icons.arrow_back_rounded,
                                color: theme.textSecondary, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textSecondary,
                          side:  BorderSide(color: theme.textMuted.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onSubmit,
                      child: const Text('Skip',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onSubmit,
                      child: const Text('Use These Lyrics',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16 + (kb > 0 ? kb : navBar)),
          ],
        ),
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  final TextEditingController controller;
  final String   label;
  final String   tag;
  final IconData icon;
  final LrcTheme theme;
  final FocusNode?            focusNode;
  final ValueChanged<String>? onChanged;

  const _MetaField({
    required this.controller,
    required this.label,
    required this.tag,
    required this.icon,
    required this.theme,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode:  focusNode,
    onChanged:  onChanged,
    style:      TextStyle(color: theme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText:   label,
      prefixIcon:  Icon(icon, size: 18, color: theme.textMuted),
      suffixText:  tag,
      suffixStyle: TextStyle(
        fontSize:      12,
        fontWeight:    FontWeight.w600,
        color:         theme.textMuted,
        fontFamily:    'monospace',
        letterSpacing: -0.3,
      ),
    ),
  );
}

class _MetadataSection extends StatefulWidget {
  final LrcSession session;
  final LrcTheme   theme;
  final bool       minimal;

  const _MetadataSection({
    required this.session,
    required this.theme,
    required this.minimal,
  });

  @override
  State<_MetadataSection> createState() => _MetadataSectionState();
}

class _MetadataSectionState extends State<_MetadataSection> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  final FocusNode _titleFocus  = FocusNode();
  final FocusNode _artistFocus = FocusNode();
  final FocusNode _albumFocus  = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleCtrl  = TextEditingController(text: widget.session.title);
    _artistCtrl = TextEditingController(text: widget.session.artist);
    _albumCtrl  = TextEditingController(text: widget.session.album);
  }

  @override
  void didUpdateWidget(_MetadataSection old) {
    super.didUpdateWidget(old);
    if (!_titleFocus.hasFocus && widget.session.title != _titleCtrl.text) {
      _titleCtrl.text = widget.session.title;
    }
    if (!_artistFocus.hasFocus && widget.session.artist != _artistCtrl.text) {
      _artistCtrl.text = widget.session.artist;
    }
    if (!_albumFocus.hasFocus && widget.session.album != _albumCtrl.text) {
      _albumCtrl.text = widget.session.album;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _titleFocus.dispose();
    _artistFocus.dispose();
    _albumFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme   = widget.theme;
    final session = widget.session;

    return Container(
      margin:     const EdgeInsets.fromLTRB(0, 0, 0, 14),
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        theme.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color:        theme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.album_rounded, color: theme.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Text('Song Metadata', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.minimal
            ? 'Minimal Metadata is ON — these tags will be left out on export'
          : 'Embedded as [ti:] [ar:] [al:] [length:] tags on export',
          style: TextStyle(fontSize: 11, color: theme.textMuted),
          ),
          if (!widget.minimal && session.audioDuration > Duration.zero) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: theme.textMuted),
                const SizedBox(width: 5),
                Text(
                  'Length: ${session.formatDuration(session.audioDuration)} '
                '(detected from audio, added automatically)',
                style: TextStyle(fontSize: 11, color: theme.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _MetaField(
            controller: _titleCtrl,
            focusNode:  _titleFocus,
            label:      'Title',
            tag:        '[ti:]',
            icon:       Icons.music_note_rounded,
            theme:      theme,
            onChanged:  session.setTitle,
          ),
          const SizedBox(height: 8),
          _MetaField(
            controller: _artistCtrl,
            focusNode:  _artistFocus,
            label:      'Artist',
            tag:        '[ar:]',
            icon:       Icons.person_rounded,
            theme:      theme,
            onChanged:  session.setArtist,
          ),
          const SizedBox(height: 8),
          _MetaField(
            controller: _albumCtrl,
            focusNode:  _albumFocus,
            label:      'Album',
            tag:        '[al:]',
            icon:       Icons.album_rounded,
            theme:      theme,
            onChanged:  session.setAlbum,
          ),
        ],
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final String       sublabel;
  final LrcTheme     theme;
  final VoidCallback onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:        theme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                    Text(sublabel, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: theme.textMuted),
          ],
        ),
      ),
    ),
  );
}

class _ActionIconButton extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final LrcTheme     theme;
  final bool         enabled;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.theme,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 52,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.12) : theme.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
            ? color.withValues(alpha: 0.3)
            : theme.textMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(icon, color: enabled ? color : theme.textMuted, size: 20),
      ),
    ),
  );
}

class _AboutLinkTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   sublabel;
  final String   url;
  final LrcTheme theme;

  const _AboutLinkTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.url,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        theme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: theme.textPrimary)),
                    Text(sublabel,
                         style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: theme.textMuted),
          ],
        ),
      ),
    ),
  );
}
