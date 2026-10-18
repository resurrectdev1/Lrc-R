import 'dart:io';

import 'package:flutter/foundation.dart';

const kAudioExtensions = <String>{
  'mp3',
  'flac',
  'wav',
  'm4a',
  'aac',
  'ogg',
  'opus',
  'wma',
  'aiff',
  'alac',
};

enum LyricsStatus {
  synced,

  plainOnly,

  missing,
}

@immutable
class LibraryTrack {
  final String path;

  final String name;

  final String folder;

  final LyricsStatus status;

  const LibraryTrack({
    required this.path,
    required this.name,
    required this.folder,
    required this.status,
  });

  String get baseName => name.replaceAll(RegExp(r'\.[^.]+$'), '');

  String get lrcPath => _swapExtension(path, 'lrc');
  String get txtPath => _swapExtension(path, 'txt');

  LibraryTrack withStatus(LyricsStatus s) =>
      LibraryTrack(path: path, name: name, folder: folder, status: s);

  static String _swapExtension(String p, String ext) {
    final dot = p.lastIndexOf('.');
    final slash = p.lastIndexOf(RegExp(r'[/\\]'));
    final stem = dot > slash ? p.substring(0, dot) : p;
    return '$stem.$ext';
  }
}

Future<List<LibraryTrack>> scanLibrary(String rootPath) =>
    compute(_scanSync, rootPath);

@visibleForTesting
List<LibraryTrack> scanLibrarySync(String rootPath) => _scanSync(rootPath);

List<LibraryTrack> _scanSync(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) return const [];

  final audio = <String>[];
  final lyricStems = <String, LyricsStatus>{};

  void walk(Directory dir) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final e in entries) {
      if (e is Directory) {
        final n = _basename(e.path);
        if (n.startsWith('.')) continue;
        walk(e);
      } else if (e is File) {
        final n = _basename(e.path);
        if (n.startsWith('.')) continue;
        final ext = _extension(n);
        if (kAudioExtensions.contains(ext)) {
          audio.add(e.path);
        } else if (ext == 'lrc') {
          lyricStems[_stem(e.path)] = LyricsStatus.synced;
        } else if (ext == 'txt') {
          lyricStems.putIfAbsent(_stem(e.path), () => LyricsStatus.plainOnly);
        }
      }
    }
  }

  walk(root);

  final tracks = audio.map((p) {
    final name = _basename(p);
    final parent = p.substring(0, p.length - name.length);
    var rel = parent.startsWith(rootPath)
        ? parent.substring(rootPath.length)
        : parent;
    rel = rel.replaceAll(RegExp(r'^[/\\]+|[/\\]+$'), '');
    return LibraryTrack(
      path: p,
      name: name,
      folder: rel,
      status: lyricStems[_stem(p)] ?? LyricsStatus.missing,
    );
  }).toList();

  tracks.sort((a, b) {
    final f = a.folder.toLowerCase().compareTo(b.folder.toLowerCase());
    return f != 0 ? f : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return tracks;
}

String _basename(String p) => p.substring(p.lastIndexOf(RegExp(r'[/\\]')) + 1);

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _stem(String p) {
  final dot = p.lastIndexOf('.');
  final slash = p.lastIndexOf(RegExp(r'[/\\]'));
  return (dot > slash ? p.substring(0, dot) : p).toLowerCase();
}
