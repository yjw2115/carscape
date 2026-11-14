import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_palette.dart';

/// The app icon, shared by the launcher, the web build and the home logo.
const appIconAsset = 'assets/brand/app_icon.png';

/// Floating "liquid glass" app mark in the top-right corner.
class GlassLogo extends StatelessWidget {
  const GlassLogo({super.key, required this.s, required this.palette});

  final double s;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(46 * s);
    return Semantics(
      header: true,
      label: 'Carscape',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0x59000000),
              blurRadius: 44 * s,
              offset: Offset(0, 18 * s),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26 * s, sigmaY: 26 * s),
            child: Container(
              height: 92 * s,
              padding: EdgeInsets.fromLTRB(20 * s, 0, 34 * s, 0),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: palette.glassBorder, width: 1.5 * s),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.glassTint,
                    palette.glassTintSoft,
                    palette.glassTint,
                  ],
                  stops: const [0, 0.6, 1],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Same mark as the launcher icon (tool/make_app_icon.py).
                  Image.asset(
                    appIconAsset,
                    width: 56 * s,
                    height: 56 * s,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                  SizedBox(width: 16 * s),
                  Text(
                    'Carscape',
                    style: TextStyle(
                      fontSize: 38 * s,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4 * s,
                      color: palette.onGlass,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
