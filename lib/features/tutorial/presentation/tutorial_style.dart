import 'package:flutter/material.dart';

abstract final class TutorialColors {
  static const background = Color(0xFF080F19);
  static const panel = Color(0xFF101E2C);
  static const border = Color(0xFF24394A);
  static const ice = Color(0xFF8FD3F4);
  static const text = Color(0xFFEDF2F4);
  static const muted = Color(0xFF9BAFBE);
  static const warm = Color(0xFFF2AF71);
  static const success = Color(0xFFA1DDBB);
  static const warning = Color(0xFFEA9587);
  static const seatColors = [
    Color(0xFFF2AF71),
    Color(0xFF8FD3F4),
    Color(0xFFBFA8EA),
    Color(0xFFA1DDBB),
  ];
}

ThemeData tutorialTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: TutorialColors.background,
  colorScheme: const ColorScheme.dark(
    primary: TutorialColors.ice,
    secondary: TutorialColors.warm,
    surface: TutorialColors.panel,
    onSurface: TutorialColors.text,
  ),
  fontFamily: 'NotoSansKR',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodyLarge: TextStyle(fontSize: 18, height: 1.5),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: TutorialColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15),
    ),
  ),
);

String formatTime(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
