import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/lrc_theme.dart';

class LrcSettings extends ChangeNotifier {
  LrcThemeMode _themeMode = LrcThemeMode.darkSlate;
  bool _materialYou = false;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;

  bool _keepScreenOn = false;
  int _timestampOffsetMs = 0;
  bool _minimalMetadata = false;
  Color? _customAccent;

  bool get keepScreenOn => _keepScreenOn;
  int get timestampOffsetMs => _timestampOffsetMs;
  bool get minimalMetadata => _minimalMetadata;

  LrcThemeMode get themeMode => _themeMode;
  bool get materialYou => _materialYou;
  bool get hasDynamicColors => _dynamicLight != null || _dynamicDark != null;
  Color? get customAccent => _customAccent;
  LrcTheme get theme => LrcTheme(
    mode: _themeMode,
    materialYou: _materialYou,
    dynamicLight: _dynamicLight,
    dynamicDark: _dynamicDark,
    customAccent: _customAccent,
  );

  Future<void> init(ColorScheme? dynamicLight, ColorScheme? dynamicDark) async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getInt('lrc_theme_base');
    if (savedBase != null) {
      if (savedBase >= 0 && savedBase < LrcThemeMode.values.length) {
        _themeMode = LrcThemeMode.values[savedBase];
      }
      _materialYou = prefs.getBool('lrc_material_you') ?? false;
    } else {
      switch (prefs.getInt('lrc_theme_mode') ?? 0) {
        case 1:
          _themeMode = LrcThemeMode.amoledBlack;
        case 2:
          _themeMode = LrcThemeMode.darkSlate;
          _materialYou = true;
        case 3:
          _themeMode = LrcThemeMode.whiteMinimal;
        default:
          _themeMode = LrcThemeMode.darkSlate;
      }
    }
    _keepScreenOn = prefs.getBool('lrc_keep_screen_on') ?? false;
    _timestampOffsetMs = prefs.getInt('lrc_timestamp_offset') ?? 0;
    _minimalMetadata = prefs.getBool('lrc_minimal_metadata') ?? false;
    final accentInt = prefs.getInt('lrc_custom_accent');
    if (accentInt != null) _customAccent = Color(accentInt);
    _dynamicLight = dynamicLight;
    _dynamicDark = dynamicDark;
    notifyListeners();
  }

  void applyDynamicColorsIfChanged(ColorScheme? light, ColorScheme? dark) {
    if (light?.primary == _dynamicLight?.primary &&
        light?.surface == _dynamicLight?.surface &&
        dark?.primary == _dynamicDark?.primary &&
        dark?.surface == _dynamicDark?.surface) {
      return;
    }
    _dynamicLight = light;
    _dynamicDark = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setThemeMode(LrcThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lrc_theme_base', mode.index);
    await prefs.setBool('lrc_material_you', _materialYou);
    notifyListeners();
  }

  Future<void> setMaterialYou(bool value) async {
    _materialYou = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lrc_material_you', value);
    await prefs.setInt('lrc_theme_base', _themeMode.index);
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

  Future<void> setCustomAccent(Color? color) async {
    _customAccent = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('lrc_custom_accent');
    } else {
      await prefs.setInt('lrc_custom_accent', color.toARGB32());
    }
    notifyListeners();
  }
}
