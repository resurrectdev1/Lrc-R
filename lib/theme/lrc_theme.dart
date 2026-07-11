import 'package:flutter/material.dart';

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


