import 'package:flutter/material.dart';

enum LrcThemeMode { darkSlate, amoledBlack, materialYou, whiteMinimal }

class LrcTheme {
  final LrcThemeMode mode;
  final ColorScheme? dynamicScheme;
  final Color? customAccent;
  const LrcTheme({required this.mode, this.dynamicScheme, this.customAccent});

  Color get bg {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF080E18);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFF5F5F5);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.surface ?? const Color(0xFF080E18);
    }
  }

  Color get surface {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF0D1623);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF0A0A0A);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFFFFFFF);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.surfaceContainerLow ?? const Color(0xFF0D1623);
    }
  }

  Color get surfaceHigh {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF122035);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF121212);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFE8E8E8);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.surfaceContainerHigh ?? const Color(0xFF122035);
    }
  }

  Color get cardBg {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF0F1C30);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFFFAFAFA);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.surfaceContainer ?? const Color(0xFF0F1C30);
    }
  }

  Color get primary {
    if (_useCustomAccent) return customAccent!;
    return defaultPrimary;
  }

  bool get _useCustomAccent =>
      customAccent != null && mode != LrcThemeMode.materialYou;

  Color get defaultPrimary {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF2261A1);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF2261A1);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF1D68A2);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.primary ?? const Color(0xFF2261A1);
    }
  }

  Color get textPrimary {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFFE4EDF8);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFFFFFFFF);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF1A1A1A);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.onSurface ?? const Color(0xFFE4EDF8);
    }
  }

  Color get textSecondary {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF7A9CC4);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFFAAAAAA);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF666666);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.onSurfaceVariant ?? const Color(0xFF7A9CC4);
    }
  }

  Color get textMuted {
    switch (mode) {
      case LrcThemeMode.darkSlate:
        return const Color(0xFF2E4D6E);
      case LrcThemeMode.amoledBlack:
        return const Color(0xFF555555);
      case LrcThemeMode.whiteMinimal:
        return const Color(0xFF999999);
      case LrcThemeMode.materialYou:
        return dynamicScheme?.outline ?? const Color(0xFF2E4D6E);
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
    if (_useCustomAccent) return customAccent!;
    if (mode == LrcThemeMode.materialYou) {
      return dynamicScheme?.primary ?? _accentBlueDefault;
    }
    return _accentBlueDefault;
  }

  Color get accentTeal {
    if (mode == LrcThemeMode.materialYou) {
      return dynamicScheme?.tertiary ?? _accentTealDefault;
    }
    return _accentTealDefault;
  }

  Color get accentPurple {
    if (mode == LrcThemeMode.materialYou) {
      return dynamicScheme?.secondary ?? _accentPurpleDefault;
    }
    return _accentPurpleDefault;
  }

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
