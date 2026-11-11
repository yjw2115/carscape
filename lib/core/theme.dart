import 'package:flutter/material.dart';

/// Design tokens from CLAUDE.md (시안 기준). Shared by every feature.
abstract final class AppColors {
  static const background = Color(0xFF0B0B0E);
  static const panel = Color(0xFF15161B);
  static const border = Color(0xFF2A2D35);
  static const text = Color(0xFFECEAE4);
  static const muted = Color(0xFFA9A69E);
  static const faint = Color(0xFF6A675F);
  static const amber = Color(0xFFE8A33D);
  static const ice = Color(0xFF8FD3F4);
  static const warm = Color(0xFFF2A65A);
  static const success = Color(0xFF9BE0B8);
  static const warning = Color(0xFFE07A6A);
  static const gold = Color(0xFFE8C26A);
}

// ponytail: titles use NotoSansKR w900 and labels use the platform monospace;
// bundle Noto Serif KR / IBM Plex Mono when the visual polish pass happens.
abstract final class AppText {
  static const title = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.3,
  );
  static const label = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    letterSpacing: 3,
    color: AppColors.amber,
  );
}

ThemeData appTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.amber,
    onPrimary: Color(0xFF1A1408),
    secondary: AppColors.ice,
    surface: AppColors.panel,
    onSurface: AppColors.text,
    error: AppColors.warning,
  ),
  fontFamily: 'NotoSansKR',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodyLarge: TextStyle(fontSize: 18, height: 1.5),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15),
    ),
  ),
);
