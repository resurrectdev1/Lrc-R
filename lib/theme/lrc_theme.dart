import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LrcThemeMode { darkSlate, amoledBlack, materialYou, whiteMinimal }

class LrcTheme {
  final LrcThemeMode mode;
  final ColorScheme? dynamicScheme;
  const LrcTheme({required this.mode, this.dynamicScheme});

  Color get bg {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF080E18);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal: return const Color(0xFFF5F5F5);
      case LrcThemeMode.materialYou:  return dynamicScheme?.surface ?? const Color(0xFF080E18);
    }
  }

  Color get surface {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF0D1623);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF0A0A0A);
      case LrcThemeMode.whiteMinimal: return const Color(0xFFFFFFFF);
      case LrcThemeMode.materialYou:  return dynamicScheme?.surfaceContainerLow ?? const Color(0xFF0D1623);
    }
  }

  Color get surfaceHigh {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF122035);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF121212);
      case LrcThemeMode.whiteMinimal: return const Color(0xFFE8E8E8);
      case LrcThemeMode.materialYou:  return dynamicScheme?.surfaceContainerHigh ?? const Color(0xFF122035);
    }
  }

  Color get cardBg {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF0F1C30);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal: return const Color(0xFFFAFAFA);
      case LrcThemeMode.materialYou:  return dynamicScheme?.surfaceContainer ?? const Color(0xFF0F1C30);
    }
  }

  Color get primary {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF2261A1);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF2261A1);
      case LrcThemeMode.whiteMinimal: return const Color(0xFF1D68A2);
      case LrcThemeMode.materialYou:  return dynamicScheme?.primary ?? const Color(0xFF2261A1);
    }
  }

  Color get textPrimary {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFFE4EDF8);
      case LrcThemeMode.amoledBlack:  return const Color(0xFFFFFFFF);
      case LrcThemeMode.whiteMinimal: return const Color(0xFF1A1A1A);
      case LrcThemeMode.materialYou:  return dynamicScheme?.onSurface ?? const Color(0xFFE4EDF8);
    }
  }

  Color get textSecondary {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF7A9CC4);
      case LrcThemeMode.amoledBlack:  return const Color(0xFFAAAAAA);
      case LrcThemeMode.whiteMinimal: return const Color(0xFF666666);
      case LrcThemeMode.materialYou:  return dynamicScheme?.onSurfaceVariant ?? const Color(0xFF7A9CC4);
    }
  }

  Color get textMuted {
    switch (mode) {
      case LrcThemeMode.darkSlate:    return const Color(0xFF2E4D6E);
      case LrcThemeMode.amoledBlack:  return const Color(0xFF555555);
      case LrcThemeMode.whiteMinimal: return const Color(0xFF999999);
      case LrcThemeMode.materialYou:  return dynamicScheme?.outline ?? const Color(0xFF2E4D6E);
    }
  }

  Brightness get brightness {
    switch (mode) {
      case LrcThemeMode.whiteMinimal: return Brightness.light;
      default:                        return Brightness.dark;
    }
  }

  static const accentBlue   = Color(0xFF2261A1);
  static const accentBlueLight = Color(0xFF4D8FCC);
  static const accentTeal   = Color(0xFF3EC9C9);
  static const accentGreen  = Color(0xFF4CAF82);
  static const accentPurple = Color(0xFF7B68EE);
  static const errorRed     = Color(0xFFCF6679);
}

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
