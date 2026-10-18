import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/library_scanner.dart';

enum LibraryFilter { all, needsLyrics, synced }

class LrcLibrary extends ChangeNotifier {
  static const _rootKey = 'lrc_r_library_root';

  String? rootPath;
  List<LibraryTrack> tracks = const [];
  bool scanning = false;
  String? error;
  bool permissionBlocked = false;

  LibraryFilter filter = LibraryFilter.all;
  String query = '';

  bool get hasFolder => rootPath != null;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      rootPath = prefs.getString(_rootKey);
    } catch (_) {}
  }

  Future<void> chooseFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose your music folder',
    );
    if (dir == null) return;
    rootPath = dir;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rootKey, dir);
    } catch (_) {}
    await rescan();
  }

  Future<void> rescan() async {
    final root = rootPath;
    if (root == null || scanning) return;
    error = null;
    permissionBlocked = false;

    if (!await _ensureReadAccess()) {
      error = 'Lrc-R needs access to your audio files to read this folder.';
      permissionBlocked = true;
      notifyListeners();
      return;
    }

    scanning = true;
    notifyListeners();
    try {
      tracks = await scanLibrary(root);
      if (tracks.isEmpty) {
        error = 'No audio files found in this folder.';
      }
    } catch (e) {
      error = 'Could not read this folder.';
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureReadAccess() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    if (await Permission.audio.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    if ((await Permission.audio.request()).isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  void setFilter(LibraryFilter f) {
    filter = f;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void markStatus(String audioPath, LyricsStatus status) {
    final i = tracks.indexWhere((t) => t.path == audioPath);
    if (i == -1) return;
    final next = [...tracks];
    next[i] = next[i].withStatus(status);
    tracks = next;
    notifyListeners();
  }

  int get syncedCount =>
      tracks.where((t) => t.status == LyricsStatus.synced).length;

  List<LibraryTrack> get visible {
    final q = query.trim().toLowerCase();
    return tracks.where((t) {
      final passes = switch (filter) {
        LibraryFilter.all => true,
        LibraryFilter.needsLyrics => t.status != LyricsStatus.synced,
        LibraryFilter.synced => t.status == LyricsStatus.synced,
      };
      if (!passes) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.folder.toLowerCase().contains(q);
    }).toList();
  }

  LibraryTrack? nextNeedingLyrics(String? currentPath) {
    if (tracks.isEmpty) return null;
    final start = currentPath == null
        ? -1
        : tracks.indexWhere((t) => t.path == currentPath);
    for (var step = 1; step <= tracks.length; step++) {
      final t = tracks[(start + step) % tracks.length];
      if (t.path != currentPath && t.status != LyricsStatus.synced) return t;
    }
    return null;
  }
}
