import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two confetti cannons fire from the bottom corners, then a second, smaller
/// volley follows. Drawn once when the story is cleared.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.seed = 7});

  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 5000);
  late final _clock = AnimationController(vsync: this, duration: _length);
  late final _pieces = _volley(math.Random(widget.seed));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (!_clock.isAnimating && _clock.value == 0) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const Key('confetti'),
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _clock, _length),
      ),
    ),
  );
}

const _colors = [
  Color(0xFFE4DCD3), // Hyundai Sand
  Color(0xFFF2AF71),
  Color(0xFF8FD3F4),
  Color(0xFFFFDA4D),
  Color(0xFFFF6B5B),
  Color(0xFFA1DDBB),
  Color(0xFFBFA8EA),
  Color(0xFF00AAD2),
];

class _Piece {
  const _Piece({
    required this.origin,
    required this.velocity,
    required this.delay,
    required this.size,
    required this.color,
    required this.spin,
    required this.flutter,
    required this.round,
  });

  /// Fractions of the screen.
  final Offset origin;

  /// Screen heights per second.
  final Offset velocity;
  final double delay, size, spin, flutter;
  final Color color;
  final bool round;
}

List<_Piece> _volley(math.Random random) {
  double between(double a, double b) => a + random.nextDouble() * (b - a);
  final pieces = <_Piece>[];
  for (final wave in [(delay: 0.0, count: 70), (delay: .55, count: 40)]) {
    for (final left in [true, false]) {
      for (var i = 0; i < wave.count; i++) {
        // Aim up and inward, fanned out around 62° from the floor.
        final angle = between(50, 78) * math.pi / 180;
        final speed = between(1.15, 2.25);
        final direction = left ? 1 : -1;
        pieces.add(
          _Piece(
            origin: Offset(left ? .02 : .98, 1.02),
            velocity: Offset(
              direction * math.cos(angle) * speed,
              -math.sin(angle) * speed,
            ),
            delay: wave.delay + between(0, .12),
            size: between(9, 17),
            color: _colors[random.nextInt(_colors.length)],
            spin: between(-9, 9),
            flutter: between(5, 11),
            round: random.nextDouble() < .22,
          ),
        );
      }
    }
  }
  return pieces;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.clock, this.length)
    : super(repaint: clock);

  final List<_Piece> pieces;
  final Animation<double> clock;
  final Duration length;
  static const _drag = 1.6;

  /// Paper falls at a slow, steady speed once the launch has spent itself.
  static const _fallSpeed = .22;

  @override
  void paint(Canvas canvas, Size size) {
    if (clock.value >= 1 || size.isEmpty) return;
    final now = clock.value * length.inMilliseconds / 1000;
    final h = size.height;
    final paint = Paint();
    for (final piece in pieces) {
      final t = now - piece.delay;
      if (t <= 0) continue;
      // Air drag spends the launch; then the paper drifts down and sways.
      final launch = (1 - math.exp(-_drag * t)) / _drag;
      final x =
          piece.origin.dx * size.width +
          piece.velocity.dx * h * launch +
          math.sin(t * piece.flutter * .6) * 12;
      final y =
          piece.origin.dy * h +
          (_fallSpeed * t + (piece.velocity.dy - _fallSpeed) * launch) * h;
      if (y > h + 40) continue;
      final fade = (1 - (t - 3.4) / 1.2).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      paint.color = piece.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size * .36, paint);
      } else {
        // Flip around one axis so each strip flickers as it falls.
        canvas.scale(1, math.cos(t * piece.flutter).abs() * .85 + .15);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * .48,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.pieces != pieces;
}
