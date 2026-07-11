import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/lrc_theme.dart';

class LrcSettings extends ChangeNotifier {
  LrcThemeMode _themeMode      = LrcThemeMode.darkSlate;
  ColorScheme? _dynamicScheme;

  bool _keepScreenOn         = false;
  int  _timestampOffsetMs    = 0;
  bool _minimalMetadata      = false;

  bool get keepScreenOn      => _keepScreenOn;
  int  get timestampOffsetMs => _timestampOffsetMs;
  bool get minimalMetadata   => _minimalMetadata;

  LrcThemeMode get themeMode => _themeMode;
  LrcTheme     get theme     => LrcTheme(mode: _themeMode, dynamicScheme: _dynamicScheme);

  Future<void> init(ColorScheme? dynamicLight, ColorScheme? dynamicDark) async {
    final prefs      = await SharedPreferences.getInstance();
    final savedTheme = prefs.getInt('lrc_theme_mode') ?? 0;
    if (savedTheme < LrcThemeMode.values.length) {
      _themeMode = LrcThemeMode.values[savedTheme];
    }
    _keepScreenOn      = prefs.getBool('lrc_keep_screen_on') ?? false;
    _timestampOffsetMs = prefs.getInt('lrc_timestamp_offset') ?? 0;
    _minimalMetadata   = prefs.getBool('lrc_minimal_metadata') ?? false;
    _dynamicScheme     = dynamicDark;
    notifyListeners();
  }

  void applyDynamicColorsIfChanged(ColorScheme? light, ColorScheme? dark) {
    final next = dark ?? light;
    if (next?.primary == _dynamicScheme?.primary &&
      next?.surface == _dynamicScheme?.surface) {
      return;
      }
      _dynamicScheme = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setThemeMode(LrcThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lrc_theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lrc_keep_screen_on', value);
    notifyListeners();
  }

  Future<void> setTimestampOffset(int ms) async {
    _timestampOffsetMs = ms.clamp(-500, 500);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lrc_timestamp_offset', _timestampOffsetMs);
    notifyListeners();
  }

  Future<void> setMinimalMetadata(bool value) async {
    _minimalMetadata = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lrc_minimal_metadata', value);
    notifyListeners();
  }
}
