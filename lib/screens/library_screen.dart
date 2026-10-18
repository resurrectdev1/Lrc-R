import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/lrc_session.dart';
import '../providers/lrc_library.dart';
import '../providers/lrc_settings.dart';
import '../services/library_scanner.dart';
import '../theme/lrc_theme.dart';
import '../theme/transitions.dart';
import '../widgets/press_scale.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lib = context.read<LrcLibrary>();
      if (lib.hasFolder && lib.tracks.isEmpty) lib.rescan();
    });
  }

  Future<void> _open(LibraryTrack track) async {
    final session = context.read<LrcSession>();
    final theme = context.read<LrcSettings>().theme;

    if (session.currentTrack?.path != track.path && session.taggedCount > 0) {
      final ok = await showLrcDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Switch song?',
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You have ${session.taggedCount} tagged line(s) that are not '
            'saved. Opening another song will discard them.',
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
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    await session.openTrack(track);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<LrcSettings>().theme;
    final lib = context.watch<LrcLibrary>();
    final currentPath = context.select<LrcSession, String?>(
      (s) => s.currentTrack?.path,
    );

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textSecondary),
        title: Text(
          'L I B R A R Y',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 6,
          ),
        ),
        actions: [
          if (lib.hasFolder) ...[
            IconButton(
              tooltip: 'Rescan',
              icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
              onPressed: lib.scanning ? null : lib.rescan,
            ),
            IconButton(
              tooltip: 'Change folder',
              icon: Icon(Icons.folder_open_rounded, color: theme.textSecondary),
              onPressed: lib.scanning ? null : lib.chooseFolder,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: !lib.hasFolder
          ? _EmptyLibrary(theme: theme, onChoose: lib.chooseFolder)
          : Column(
              children: [
                _Header(lib: lib, theme: theme),
                if (lib.error != null) _ErrorBanner(lib: lib, theme: theme),
                Expanded(
                  child: lib.scanning && lib.tracks.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primary,
                          ),
                        )
                      : _TrackList(
                          lib: lib,
                          theme: theme,
                          currentPath: currentPath,
                          onOpen: _open,
                        ),
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final LrcLibrary lib;
  final LrcTheme theme;
  const _Header({required this.lib, required this.theme});

  @override
  Widget build(BuildContext context) {
    final total = lib.tracks.length;
    final done = lib.syncedCount;
    final folderName = lib.rootPath!
        .split(RegExp(r'[/\\]'))
        .where((p) => p.isNotEmpty)
        .lastOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folderName ?? lib.rootPath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$done / $total synced',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: lib.scanning ? null : (total == 0 ? 0 : done / total),
              minHeight: 4,
              color: LrcTheme.accentGreen,
              backgroundColor: theme.textMuted.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: lib.setQuery,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search songs or folders',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: theme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (f, label) in const [
                (LibraryFilter.all, 'All'),
                (LibraryFilter.needsLyrics, 'Needs lyrics'),
                (LibraryFilter.synced, 'Synced'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: lib.filter == f,
                    onSelected: (_) => lib.setFilter(f),
                    selectedColor: theme.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: lib.filter == f
                          ? theme.primary
                          : theme.textSecondary,
                    ),
                    side: BorderSide(
                      color: lib.filter == f
                          ? theme.primary.withValues(alpha: 0.4)
                          : theme.textMuted.withValues(alpha: 0.3),
                    ),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final LrcLibrary lib;
  final LrcTheme theme;
  const _ErrorBanner({required this.lib, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LrcTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              lib.error!,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
          if (lib.permissionBlocked)
            TextButton(
              onPressed: () async {
                await lib.rescan();
                if (lib.permissionBlocked) await openAppSettings();
              },
              child: const Text('Allow'),
            ),
        ],
      ),
    );
  }
}

sealed class _Row {}

class _FolderRow extends _Row {
  final String label;
  _FolderRow(this.label);
}

class _TrackRow extends _Row {
  final LibraryTrack track;
  _TrackRow(this.track);
}

class _TrackList extends StatelessWidget {
  final LrcLibrary lib;
  final LrcTheme theme;
  final String? currentPath;
  final Future<void> Function(LibraryTrack) onOpen;

  const _TrackList({
    required this.lib,
    required this.theme,
    required this.currentPath,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final visible = lib.visible;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          lib.tracks.isEmpty ? '' : 'Nothing matches.',
          style: TextStyle(color: theme.textMuted),
        ),
      );
    }

    final rows = <_Row>[];
    String? lastFolder;
    for (final t in visible) {
      if (t.folder != lastFolder) {
        rows.add(_FolderRow(t.folder.isEmpty ? 'This folder' : t.folder));
        lastFolder = t.folder;
      }
      rows.add(_TrackRow(t));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final row = rows[i];
        if (row is _FolderRow) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              row.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: theme.textMuted,
              ),
            ),
          );
        }
        final t = (row as _TrackRow).track;
        return _TrackTile(
          track: t,
          theme: theme,
          isCurrent: t.path == currentPath,
          onTap: () => onOpen(t),
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  final LibraryTrack track;
  final LrcTheme theme;
  final bool isCurrent;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.theme,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (track.status) {
      LyricsStatus.synced => (
        Icons.check_circle_rounded,
        LrcTheme.accentGreen,
        'Synced',
      ),
      LyricsStatus.plainOnly => (
        Icons.notes_rounded,
        theme.accentTeal,
        'Plain lyrics, not synced',
      ),
      LyricsStatus.missing => (
        Icons.radio_button_unchecked_rounded,
        theme.textMuted,
        'No lyrics',
      ),
    };

    return PressScale(
      scale: 0.99,
      child: ListTile(
        onTap: onTap,
        selected: isCurrent,
        selectedTileColor: theme.primary.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          track.baseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          label,
          style: TextStyle(color: theme.textMuted, fontSize: 11),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final LrcTheme theme;
  final Future<void> Function() onChoose;
  const _EmptyLibrary({required this.theme, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music_rounded, size: 56, color: theme.primary),
          const SizedBox(height: 20),
          Text(
            'Your music library',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a folder and Lrc-R will find every song inside it, '
            'including subfolders, and show which ones already have synced '
            'lyrics. Saved .lrc files go right next to each song.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: PressScale(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text(
                  'Choose Folder',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: onChoose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
