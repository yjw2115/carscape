import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../home/presentation/home_palette.dart';

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
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
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
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
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
    this.width = double.infinity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Fills the available width by default; null shrink-wraps the child,
  /// e.g. for a floating pill.
  final double? width;

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
            width: width,
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

/// Button looks shared by the story screens and its dialogs.
abstract final class StoryButtons {
  static const _font = 'NotoSansKR';

  /// The main action of a screen or dialog, in Hyundai Sand.
  static ButtonStyle sand({
    Size minimumSize = const Size(150, 60),
    double fontSize = 19,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 26,
      vertical: 14,
    ),
    double elevation = 0,
  }) => FilledButton.styleFrom(
    backgroundColor: HyundaiColors.sand,
    foregroundColor: HyundaiColors.blue,
    disabledBackgroundColor: HyundaiColors.sand.withValues(alpha: .28),
    disabledForegroundColor: HyundaiColors.lightSand.withValues(alpha: .7),
    minimumSize: minimumSize,
    padding: padding,
    elevation: elevation,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    textStyle: TextStyle(
      fontFamily: _font,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
    ),
  );

  /// A destructive choice such as giving up.
  static ButtonStyle danger() => FilledButton.styleFrom(
    backgroundColor: TutorialColors.warning,
    foregroundColor: const Color(0xFF2A0F0B),
    minimumSize: const Size(150, 60),
    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 19,
      fontWeight: FontWeight.w800,
    ),
  );

  /// The quiet alternative: a pane of glass.
  static ButtonStyle glass() => OutlinedButton.styleFrom(
    minimumSize: const Size(130, 60),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    backgroundColor: const Color(0x1AFFFFFF),
    foregroundColor: TutorialColors.text,
    side: const BorderSide(color: Color(0x40FFFFFF), width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Every story dialog: thick frosted glass with a tinted glow, an icon badge,
/// a sheen along the top edge and its buttons on the driver's side.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.actions = const [],
    this.tint = TutorialColors.ice,
    this.maxWidth = 540,
    this.alignment,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color tint;
  final double maxWidth;

  /// Defaults to the story theme's driver-side placement.
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return Dialog(
      alignment: alignment,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              const BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 60,
                offset: Offset(0, 24),
              ),
              BoxShadow(
                color: tint.withValues(alpha: .12),
                blurRadius: 80,
                spreadRadius: -12,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: const Color(0x47FFFFFF),
                    width: 1.2,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xD91D3349),
                      Color(0xB80C1825),
                      Color(0xCC17293B),
                    ],
                    stops: [0, .55, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    // A soft light in the badge's color behind the title.
                    Positioned(
                      left: -90,
                      top: -130,
                      width: 340,
                      height: 340,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                tint.withValues(alpha: .24),
                                tint.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Sheen along the top edge, like light on curved glass.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 96,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: .11),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              GlassBadge(icon: icon, tint: tint),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.6,
                                    height: 1.3,
                                    color: TutorialColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Flexible(
                            child: SingleChildScrollView(
                              child: DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.6,
                                  color: TutorialColors.text,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: actions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round glass badge holding a dialog's or a setting's icon.
class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.icon,
    this.tint = TutorialColors.ice,
    this.size = 54,
  });

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint.withValues(alpha: .34), tint.withValues(alpha: .08)],
      ),
      border: Border.all(color: tint.withValues(alpha: .55), width: 1.2),
      boxShadow: [
        BoxShadow(color: tint.withValues(alpha: .28), blurRadius: 18),
      ],
    ),
    child: Icon(icon, color: tint, size: size * .5),
  );
}

/// A lighter pane inside a glass dialog, for one row or one group.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
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
