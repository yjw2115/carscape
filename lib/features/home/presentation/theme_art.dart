import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/escape_theme.dart';

/// Card illustrations, drawn on a 560×540 design canvas and stretched to fit.
class ThemeArtPainter extends CustomPainter {
  const ThemeArtPainter(this.art);

  final ThemeArt art;
  static const _design = Size(560, 540);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _design.width, size.height / _design.height);
    switch (art) {
      case ThemeArt.downpour:
        _downpour(canvas);
      case ThemeArt.parkingLot:
        _parkingLot(canvas);
      case ThemeArt.missingDriver:
        _missingDriver(canvas);
    }
    canvas.restore();
  }

  void _downpour(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & _design,
      Paint()..color = const Color(0xFF071629),
    );
    canvas.drawCircle(
      const Offset(420, 120),
      170,
      Paint()..color = const Color(0xFF0C2240),
    );
    final rain = Paint()
      ..color = const Color(0xCC5D86AE)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const drops = [
      Offset(50, 30),
      Offset(140, 70),
      Offset(240, 20),
      Offset(330, 90),
      Offset(520, 40),
      Offset(90, 170),
      Offset(200, 150),
      Offset(360, 200),
      Offset(520, 220),
      Offset(40, 280),
      Offset(280, 260),
      Offset(460, 300),
      Offset(150, 300),
    ];
    for (final drop in drops) {
      canvas.drawLine(drop, drop + const Offset(-14, 44), rain);
    }
    canvas.drawPath(
      Path()
        ..moveTo(472, 40)
        ..lineTo(432, 140)
        ..lineTo(468, 146)
        ..lineTo(420, 258),
      _stroke(const Color(0xFF00AAD2), 6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(70, 422)
        ..cubicTo(96, 378, 126, 358, 182, 356)
        ..lineTo(292, 356)
        ..cubicTo(340, 356, 370, 380, 392, 422)
        ..close(),
      Paint()..color = const Color(0xFF02060C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(368, 398, 24, 11),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE4DCD3),
    );
    final surface = Path()
      ..moveTo(0, 432)
      ..cubicTo(70, 416, 140, 442, 210, 432)
      ..cubicTo(280, 422, 350, 416, 420, 432)
      ..cubicTo(490, 448, 520, 440, 560, 436);
    canvas.drawPath(
      Path.from(surface)
        ..lineTo(560, 540)
        ..lineTo(0, 540)
        ..close(),
      Paint()..color = const Color(0xFF0A2A47),
    );
    canvas.drawPath(surface, _stroke(const Color(0xB300AAD2), 3));
  }

  void _parkingLot(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & _design,
      Paint()..color = const Color(0xFF16100D),
    );
    canvas.drawCircle(
      const Offset(430, 110),
      46,
      Paint()..color = const Color(0xFFE4DCD3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(126, 146)
        ..lineTo(30, 430)
        ..lineTo(222, 430)
        ..close(),
      Paint()..color = const Color(0x59A36B4F),
    );
    canvas.drawRect(
      const Rect.fromLTWH(120, 140, 12, 290),
      Paint()..color = const Color(0xFF3A2A22),
    );
    canvas.drawCircle(
      const Offset(126, 142),
      11,
      Paint()..color = const Color(0xFFE4C3A8),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 430, 560, 110),
      Paint()..color = const Color(0xFF201813),
    );
    final line = Paint()
      ..color = const Color(0xFF6E5A4C)
      ..strokeWidth = 5;
    canvas.drawLine(const Offset(260, 440), const Offset(236, 540), line);
    canvas.drawLine(const Offset(380, 440), const Offset(370, 540), line);
    canvas.drawLine(const Offset(500, 440), const Offset(504, 540), line);
  }

  void _missingDriver(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & _design,
      Paint()..color = const Color(0xFF081322),
    );
    final grid = Paint()
      ..color = const Color(0xFF17304D)
      ..strokeWidth = 2;
    for (var i = 80.0; i < 540; i += 80) {
      canvas.drawLine(Offset(0, i), Offset(560, i), grid);
      if (i < 560) canvas.drawLine(Offset(i, 0), Offset(i, 540), grid);
    }
    final route = Path()
      ..moveTo(40, 500)
      ..cubicTo(140, 470, 190, 400, 260, 370)
      ..cubicTo(330, 340, 390, 340, 430, 250)
      ..cubicTo(470, 160, 490, 90, 530, 60);
    canvas.drawPath(
      _dashed(route, 18, 14),
      _stroke(const Color(0xFFAACAE6), 7),
    );
    canvas.drawCircle(
      const Offset(530, 60),
      14,
      Paint()..color = const Color(0xFFAACAE6),
    );
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        out.addPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          Offset.zero,
        );
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(ThemeArtPainter oldDelegate) => oldDelegate.art != art;
}
