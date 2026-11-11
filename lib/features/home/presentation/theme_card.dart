import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../domain/escape_theme.dart';
import '../integration/parking_status_source.dart';
import 'home_palette.dart';
import 'theme_art.dart';

/// One theme tile. [emphasis] is 1 when the card sits in the selected slot
/// and fades to 0 as it moves away.
class ThemeCard extends StatelessWidget {
  const ThemeCard({
    super.key,
    required this.theme,
    required this.s,
    required this.size,
    required this.palette,
    required this.emphasis,
    required this.parking,
    required this.onStart,
  });

  final EscapeTheme theme;
  final double s;
  final Size size;
  final HomePalette palette;
  final double emphasis;
  final ParkingState parking;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final radius = 34 * s;
    final borderWidth = lerpDouble(2, 3, emphasis)! * s;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Color.lerp(p.cardBorder, p.selectedBorder, emphasis)!,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: p.shadow.a * emphasis),
            blurRadius: 44 * s,
            offset: Offset(0, 18 * s),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: size.height * 540 / 1146,
              child: CustomPaint(painter: ThemeArtPainter(theme.art)),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(36 * s, 36 * s, 36 * s, 24 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 56 * s,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6 * s,
                        color: p.title,
                      ),
                    ),
                    SizedBox(height: 20 * s),
                    Text(
                      theme.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24 * s,
                        height: 1.55,
                        color: p.description,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 12 * s,
                      runSpacing: 12 * s,
                      children: [
                        for (final chip in theme.chips)
                          _Chip(s: s, palette: p, label: chip),
                      ],
                    ),
                    SizedBox(height: 20 * s),
                    IgnorePointer(
                      ignoring: emphasis < 0.95,
                      child: ExcludeSemantics(
                        excluding: emphasis < 0.95,
                        child: Opacity(
                          opacity: emphasis,
                          child: StartArea(
                            s: s,
                            palette: p,
                            parking: parking,
                            onStart: onStart,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.s, required this.palette, required this.label});

  final double s;
  final HomePalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 50 * s,
    padding: EdgeInsets.symmetric(horizontal: 20 * s),
    decoration: BoxDecoration(
      color: palette.chip,
      borderRadius: BorderRadius.circular(14 * s),
    ),
    // widthFactor keeps the chip as wide as its label inside the Wrap.
    child: Center(
      widthFactor: 1,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 25 * s,
          fontWeight: FontWeight.w500,
          color: palette.onChip,
        ),
      ),
    ),
  );
}

/// Start button, or a gear notice when the car is not in P.
class StartArea extends StatelessWidget {
  const StartArea({
    super.key,
    required this.s,
    required this.palette,
    required this.parking,
    required this.onStart,
  });

  final double s;
  final HomePalette palette;
  final ParkingState parking;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final radius = BorderRadius.circular(26 * s);
    final height = 130 * s;
    switch (parking) {
      case ParkingState.parked:
        return Semantics(
          button: true,
          label: '시작하기',
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            child: Material(
              color: p.start,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onStart,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 56 * s,
                      color: p.onStart,
                    ),
                    SizedBox(width: 10 * s),
                    Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 42 * s,
                        fontWeight: FontWeight.w600,
                        color: p.onStart,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case ParkingState.notParked:
        return Semantics(
          liveRegion: true,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: p.warning,
              borderRadius: radius,
              border: Border.all(color: p.warningBorder, width: 2 * s),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 46 * s,
                    height: 46 * s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12 * s),
                      border: Border.all(color: p.onWarning, width: 3 * s),
                    ),
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontSize: 28 * s,
                        fontWeight: FontWeight.w600,
                        color: p.onWarning,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18 * s),
                Text(
                  '기어를 P단으로 바꾸세요',
                  style: TextStyle(
                    fontSize: 31 * s,
                    fontWeight: FontWeight.w500,
                    color: p.onWarning,
                  ),
                ),
              ],
            ),
          ),
        );
      case ParkingState.checking:
        return Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.checking, borderRadius: radius),
          child: Text(
            '기어 상태를 확인하고 있어요',
            style: TextStyle(
              fontSize: 30 * s,
              fontWeight: FontWeight.w500,
              color: p.description,
            ),
          ),
        );
    }
  }
}
