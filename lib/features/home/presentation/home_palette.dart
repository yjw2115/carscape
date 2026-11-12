import 'package:flutter/material.dart';

/// Hyundai CI colors (https://www.hyundai.com/kr/ko/info/ci/ci-color).
abstract final class HyundaiColors {
  static const blue = Color(0xFF002C5F);
  static const sand = Color(0xFFE4DCD3);
  static const lightSand = Color(0xFFF6F3F2);
  static const gold = Color(0xFFA36B4F);
  static const activeBlue = Color(0xFF00AAD2);
  static const skyBlue = Color(0xFFAACAE6);
  static const activeRed = Color(0xFFE63312);
}

/// Home screen colors. Dark follows a Hyundai Blue monotone with a Sand
/// accent; light uses Light Sand with Hyundai Blue as the accent.
@immutable
class HomePalette {
  const HomePalette({
    required this.background,
    required this.rail,
    required this.railBorder,
    required this.button,
    required this.onButton,
    required this.railLabel,
    required this.card,
    required this.cardBorder,
    required this.selectedBorder,
    required this.title,
    required this.description,
    required this.chip,
    required this.onChip,
    required this.start,
    required this.onStart,
    required this.warning,
    required this.warningBorder,
    required this.onWarning,
    required this.checking,
    required this.glassTint,
    required this.glassTintSoft,
    required this.glassBorder,
    required this.onGlass,
    required this.shadow,
  });

  final Color background;
  final Color rail;
  final Color railBorder;
  final Color button;
  final Color onButton;
  final Color railLabel;
  final Color card;
  final Color cardBorder;
  final Color selectedBorder;
  final Color title;
  final Color description;
  final Color chip;
  final Color onChip;
  final Color start;
  final Color onStart;
  final Color warning;
  final Color warningBorder;
  final Color onWarning;
  final Color checking;
  final Color glassTint;
  final Color glassTintSoft;
  final Color glassBorder;
  final Color onGlass;
  final Color shadow;

  static const dark = HomePalette(
    background: Color(0xFF001631),
    rail: HyundaiColors.blue,
    railBorder: Color(0xFF0D3D78),
    button: Color(0xFF123F73),
    onButton: HyundaiColors.lightSand,
    railLabel: HyundaiColors.skyBlue,
    card: Color(0xFF00224A),
    cardBorder: Color(0xFF0D3566),
    selectedBorder: HyundaiColors.sand,
    title: HyundaiColors.lightSand,
    description: Color(0xFFAFC0D4),
    chip: Color(0x29AACAE6),
    onChip: Color(0xFFCFE0F0),
    start: HyundaiColors.sand,
    onStart: HyundaiColors.blue,
    warning: Color(0xFF2B100B),
    warningBorder: HyundaiColors.activeRed,
    onWarning: Color(0xFFFF9A85),
    checking: Color(0x14FFFFFF),
    glassTint: Color(0x3DFFFFFF),
    glassTintSoft: Color(0x0DFFFFFF),
    glassBorder: Color(0x4DFFFFFF),
    onGlass: Colors.white,
    shadow: Color(0x73000000),
  );

  static const light = HomePalette(
    background: HyundaiColors.lightSand,
    rail: HyundaiColors.blue,
    railBorder: HyundaiColors.blue,
    button: Color(0xFF123F73),
    onButton: Colors.white,
    railLabel: HyundaiColors.skyBlue,
    card: Colors.white,
    cardBorder: HyundaiColors.sand,
    selectedBorder: HyundaiColors.blue,
    title: Color(0xFF0B1B30),
    description: Color(0xFF5B6675),
    chip: HyundaiColors.skyBlue,
    onChip: HyundaiColors.blue,
    start: HyundaiColors.blue,
    onStart: Colors.white,
    warning: Color(0xFFFDECE8),
    warningBorder: HyundaiColors.activeRed,
    onWarning: Color(0xFFC42A0E),
    checking: Color(0xFFEDE7E1),
    glassTint: Color(0xBFFFFFFF),
    glassTintSoft: Color(0x73FFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    onGlass: HyundaiColors.blue,
    shadow: Color(0x2E002C5F),
  );

  static HomePalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Material theme for the home screen and the pages opened from it.
ThemeData homeTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  fontFamily: 'Pretendard',
  colorScheme: ColorScheme.fromSeed(
    seedColor: HyundaiColors.blue,
    brightness: brightness,
  ),
);
