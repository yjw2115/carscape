import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../domain/escape_theme.dart';
import '../integration/parking_status_source.dart';
import 'home_palette.dart';
import 'theme_card.dart';

/// Endless theme carousel. The selected card sits next to the rail and the
/// following cards recede to the right like a wallpaper picker.
///
/// [position] is a virtual page index: page `v` shows `themes[v % length]`,
/// so the list loops without cards jumping across the screen.
class ThemeCarousel extends StatelessWidget {
  const ThemeCarousel({
    super.key,
    required this.position,
    required this.themes,
    required this.s,
    required this.originX,
    required this.palette,
    required this.parking,
    required this.onSelectPage,
    required this.onStart,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Animation<double> position;
  final List<EscapeTheme> themes;
  final double s;
  final double originX;
  final HomePalette palette;
  final ParkingState parking;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<EscapeTheme> onStart;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  static const cardWidth = 560.0;
  static const gap = 28.0;

  /// Slot -1 (leaving behind the rail) through slot 3 (entering from the right).
  static const _scales = [1.0, 1.0, 0.86, 0.74, 0.64];
  static const _opacities = [0.0, 1.0, 0.8, 0.6, 0.0];
  static final _xs = () {
    final xs = <double>[-(cardWidth + gap), 0];
    for (var slot = 1; slot <= 3; slot++) {
      xs.add(xs.last + cardWidth * _scales[slot] + gap);
    }
    return xs;
  }();

  static double slotWidth(double s) => (cardWidth + gap) * s;

  static double _at(List<double> table, double r) {
    final t = (r + 1).clamp(0.0, 4.0);
    final i = math.min(t.floor(), 3);
    return lerpDouble(table[i], table[i + 1], t - i)!;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardSize = Size(cardWidth * s, constraints.maxHeight - 64 * s);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (details) =>
            onDragEnd(details.velocity.pixelsPerSecond.dx),
        child: AnimatedBuilder(
          animation: position,
          builder: (context, _) {
            final page = position.value;
            // Slots -1 and 3 are fully transparent, so only cards strictly
            // between them are built.
            final cards = <(int, double)>[
              for (var v = page.floor(); v <= page.floor() + 3; v++)
                if (v - page > -1 && v - page < 3) (v, v - page),
            ]..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
            return Stack(
              clipBehavior: Clip.none,
              children: [for (final (v, r) in cards) _card(v, r, cardSize)],
            );
          },
        ),
      );
    },
  );

  Widget _card(int page, double r, Size cardSize) {
    final theme = themes[page % themes.length];
    final scale = _at(_scales, r);
    final selected = r.abs() < 0.05;
    final card = ThemeCard(
      theme: theme,
      s: s,
      size: cardSize,
      palette: palette,
      emphasis: (1 - r.abs()).clamp(0.0, 1.0),
      parking: parking,
      onStart: () => onStart(theme),
    );
    return Positioned(
      key: ValueKey(page),
      left: originX + _at(_xs, r) * s,
      top: 32 * s + cardSize.height * (1 - scale) / 2,
      width: cardSize.width,
      height: cardSize.height,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: Opacity(
          opacity: _at(_opacities, r).clamp(0.0, 1.0),
          child: selected
              ? card
              : Semantics(
                  button: true,
                  label: '${theme.title} 테마 보기',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onSelectPage(page),
                    child: card,
                  ),
                ),
        ),
      ),
    );
  }
}
