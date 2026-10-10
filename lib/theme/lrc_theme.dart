import 'package:flutter/material.dart';

enum LrcThemeMode { darkSlate, amoledBlack, whiteMinimal }

class LrcTheme {
  final LrcThemeMode mode;

  final bool materialYou;
  final ColorScheme? dynamicLight;
  final ColorScheme? dynamicDark;
  final Color? customAccent;
  const LrcTheme({
    required this.mode,
    this.materialYou = false,
    this.dynamicLight,
    this.dynamicDark,
    this.customAccent,
  });

  ColorScheme? get _dyn {
    if (!materialYou) return null;
    return brightness == Brightness.light ? dynamicLight : dynamicDark;
  }

  bool get _dynSurfaces => _dyn != null && mode != LrcThemeMode.amoledBlack;

  Color get bg {
    if (_dynSurfaces) return _dyn!.surface;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF080E18);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFF5F5F5);
    }
  }

  Color get surface {
    if (_dynSurfaces) return _dyn!.surfaceContainerLow;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF0D1623);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF0A0A0A);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get surfaceHigh {
    if (_dynSurfaces) return _dyn!.surfaceContainerHigh;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF122035);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF121212);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFE8E8E8);
    }
  }

  Color get cardBg {
    if (_dynSurfaces) return _dyn!.surfaceContainer;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF0F1C30);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFFAFAFA);
    }
  }

  Color get primary {
    if (_dyn != null) return _dyn!.primary;
    if (customAccent != null) return customAccent!;
    return defaultPrimary;
  }

  Color get defaultPrimary {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF2261A1);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF2261A1);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF1D68A2);
    }
  }

  Color get textPrimary {
    if (_dynSurfaces) return _dyn!.onSurface;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFFE4EDF8);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFFFFFFFF);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get textSecondary {
    if (_dynSurfaces) return _dyn!.onSurfaceVariant;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF7A9CC4);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFFAAAAAA);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF666666);
    }
  }

  Color get textMuted {
    if (_dynSurfaces) return _dyn!.outline;
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF2E4D6E);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF555555);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF999999);
    }
  }

  Brightness get brightness {
    switch (mode) {
      case LrcThemeMode.whiteMinimal:
        return Brightness.light;
      default:
        return Brightness.dark;
    }
  }

  Color get accentBlue {
    if (_dyn != null) return _dyn!.primary;
    if (customAccent != null) return customAccent!;
    return _accentBlueDefault;
  }

  Color get accentTeal => _dyn?.tertiary ?? _accentTealDefault;

  Color get accentPurple => _dyn?.secondary ?? _accentPurpleDefault;

  static const _accentBlueDefault = Color(0xFF2261A1);
  static const _accentTealDefault = Color(0xFF3EC9C9);
  static const _accentPurpleDefault = Color(0xFF7B68EE);

  static const accentBlueLight = Color(0xFF4D8FCC);
  static const accentGreen = Color(0xFF4CAF82);
  static const errorRed = Color(0xFFCF6679);

  static const List<Color> accentPresets = [
    Color(0xFF2261A1),
    Color(0xFF4D8FCC),
    Color(0xFF42A5C8),
    Color(0xFF3EC9C9),
    Color(0xFF4E8B7A),
    Color(0xFF4CAF82),
    Color(0xFF7A9E3B),
    Color(0xFFFFBF00),
    Color(0xFFC46A4A),
    Color(0xFFE5624D),
    Color(0xFFE0529C),
    Color(0xFF9E3B6B),
    Color(0xFF7B68EE),
    Color(0xFF6B7A7D),
  ];
}
