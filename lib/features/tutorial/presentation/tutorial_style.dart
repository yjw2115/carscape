import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
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

/// Frosted glass over the snow, in the home screen's liquid-glass recipe:
/// blur, a light diagonal tint, a bright rim and a soft drop shadow.
abstract final class TutorialGlass {
  static const tint = Color(0x8C1E3346);
  static const tintSoft = Color(0x6B0E1B28);
  static const rim = Color(0x4DFFFFFF);
  static const fill = Color(0x1FFFFFFF);
  static const shadow = Color(0x66000000);
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
    bodyMedium: TextStyle(fontSize: 17, height: 1.5),
    bodyLarge: TextStyle(fontSize: 19, height: 1.5),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  ),
  // Secondary buttons are small panes of glass.
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      backgroundColor: TutorialGlass.fill,
      foregroundColor: TutorialColors.text,
      side: const BorderSide(color: TutorialGlass.rim),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  // Dialogs open on the driver side, where their buttons are reachable.
  dialogTheme: DialogThemeData(
    alignment: Alignment.centerLeft,
    insetPadding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
    backgroundColor: const Color(0xF2122233),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: const BorderSide(color: TutorialGlass.rim),
    ),
    titleTextStyle: const TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: TutorialColors.text,
    ),
    contentTextStyle: const TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 18,
      height: 1.6,
      color: TutorialColors.text,
    ),
  ),
);

/// Frosted glass panel used for every card in the story.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: TutorialGlass.shadow,
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: TutorialGlass.rim, width: 1.2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TutorialGlass.tint,
                  TutorialGlass.tintSoft,
                  TutorialGlass.tint,
                ],
                stops: [0, .6, 1],
              ),
            ),
            // Sheen along the top edge, like light on curved glass.
            foregroundDecoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: .10),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The story is laid out for about [reference]. On the car's larger app
/// area (1682×1210) the whole screen — text, buttons and panels — scales up
/// together so nothing stays small; smaller windows keep the original size.
class GameZoom extends StatelessWidget {
  const GameZoom({super.key, required this.child});

  final Widget child;
  static const reference = Size(1180, 850);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (!c.hasBoundedWidth || !c.hasBoundedHeight) return child;
      final zoom = math
          .min(c.maxWidth / reference.width, c.maxHeight / reference.height)
          .clamp(1.0, 1.5);
      if (zoom == 1) return child;
      return FittedBox(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: c.maxWidth / zoom,
          height: c.maxHeight / zoom,
          child: child,
        ),
      );
    },
  );
}

String formatTime(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
