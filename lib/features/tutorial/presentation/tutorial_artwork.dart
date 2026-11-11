import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import 'tutorial_style.dart';
import 'tutorial_atmosphere.dart';

void _label(
  Canvas canvas,
  String text,
  Offset center, {
  Color color = TutorialColors.muted,
  double size = 13,
  FontWeight weight = FontWeight.w500,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'NotoSansKR',
        color: color,
        fontSize: size,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

class TutorialArtwork extends StatelessWidget {
  const TutorialArtwork({
    super.key,
    required this.controller,
    required this.time,
  });
  final TutorialController controller;
  final double time;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1926),
          border: Border.all(color: TutorialColors.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: switch (c.stage) {
          TutorialStage.ventilation => VentilationDashboard(controller: c),
          TutorialStage.escape => EscapeView(controller: c, time: time),
          _ => CustomPaint(
            painter: switch (c.stage) {
              TutorialStage.power => _CarPainter(c),
              TutorialStage.glovebox => _GloveboxPainter(c.heaterOn, time),
              _ => _SnowPainter(
                time: time,
                clear:
                    c.stage == TutorialStage.arrival ||
                    c.stage == TutorialStage.result,
                shelter:
                    c.stage == TutorialStage.arrival ||
                    c.stage == TutorialStage.result,
              ),
            },
            child: const SizedBox.expand(),
          ),
        },
      ),
    );
  }
}

class SnowBackdrop extends StatelessWidget {
  const SnowBackdrop({super.key, required this.time, this.shelter = false});
  final double time;
  final bool shelter;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SnowPainter(time: time, clear: shelter, shelter: shelter),
    child: const SizedBox.expand(),
  );
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.c);
  final TutorialController c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scale = math.min(w / 490, h / 400);
    canvas.save();
    canvas.translate((w - 490 * scale) / 2, (h - 400 * scale) / 2);
    canvas.scale(scale);
    final grid = Paint()..color = TutorialColors.ice.withValues(alpha: 0.055);
    for (double x = 0; x < 490; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, 400), grid);
    }
    for (double y = 0; y < 400; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(490, y), grid);
    }
    final outline = Paint()
      ..color = TutorialColors.ice.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final car = RRect.fromRectAndRadius(
      const Rect.fromLTWH(137, 35, 216, 327),
      const Radius.circular(55),
    );
    canvas.drawRRect(car, Paint()..color = const Color(0xFF0E2131));
    canvas.drawRRect(car, outline);
    final windscreen = Path()
      ..moveTo(163, 81)
      ..quadraticBezierTo(245, 59, 327, 81)
      ..lineTo(316, 116)
      ..lineTo(174, 116)
      ..close();
    canvas.drawPath(
      windscreen,
      Paint()..color = TutorialColors.ice.withValues(alpha: .08),
    );
    canvas.drawPath(windscreen, outline);
    canvas.drawLine(const Offset(151, 296), const Offset(339, 296), outline);
    for (final x in [127.0, 353.0]) {
      for (final y in [96.0, 250.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 10, 47),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF324350),
        );
      }
    }
    const positions = [
      Offset(195, 250),
      Offset(295, 250),
      Offset(195, 160),
      Offset(295, 160),
    ];
    const battery = Offset(245, 326);
    if (c.stage == TutorialStage.power) {
      var from = battery;
      for (int i = 0; i < 4; i++) {
        final p = positions[i];
        final path = Path()..moveTo(from.dx, from.dy);
        if (i == 0) path.lineTo(from.dx, p.dy);
        path.lineTo(p.dx, p.dy);
        final active = i < c.powerCount;
        canvas.drawPath(
          path,
          Paint()
            ..color = active
                ? TutorialColors.warm
                : TutorialColors.ice.withValues(alpha: .38)
            ..strokeWidth = active ? 4 : 2
            ..style = PaintingStyle.stroke,
        );
        from = p;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(220, 311, 50, 28),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF402E22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(220, 311, 50, 28),
          const Radius.circular(5),
        ),
        Paint()
          ..color = TutorialColors.warm
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _label(canvas, '+  −', battery, color: TutorialColors.warm, size: 17);
      _label(
        canvas,
        '트렁크 · 배터리',
        const Offset(245, 355),
        color: TutorialColors.warm,
        size: 12,
      );
    } else {
      _label(
        canvas,
        '모두의 안전을 확인하세요',
        const Offset(245, 327),
        color: TutorialColors.success,
        size: 14,
      );
    }
    for (final seat in CarSeat.values) {
      final p = positions[seat.index];
      final connected = c.lights[seat]!;
      const color = TutorialColors.warm;
      if (connected) {
        canvas.drawCircle(
          p,
          39,
          Paint()
            ..color = color.withValues(alpha: .10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 54, height: 56),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..color = connected
              ? const Color(0xFF473A2D)
              : const Color(0xFF112638),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..color = connected ? color : TutorialColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = connected
              ? color
              : TutorialColors.ice.withValues(alpha: .32),
      );
      canvas.drawLine(
        p.translate(-5, 15),
        p.translate(5, 15),
        Paint()
          ..color = connected
              ? color
              : TutorialColors.ice.withValues(alpha: .32)
          ..strokeWidth = 3,
      );
      final labelX = seat == CarSeat.rearLeft || seat == CarSeat.driver
          ? 72.0
          : 418.0;
      _label(
        canvas,
        seat.label,
        Offset(labelX, p.dy - 7),
        color: connected ? color : TutorialColors.muted,
        size: 13,
      );
      _label(
        canvas,
        connected ? 'ON' : 'OFF',
        Offset(labelX, p.dy + 15),
        color: connected ? color : TutorialColors.muted,
        size: 12,
      );
    }
    _label(
      canvas,
      '차량 앞쪽 ↑',
      const Offset(245, 18),
      color: TutorialColors.ice,
      size: 12,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) => true;
}

class _GloveboxPainter extends CustomPainter {
  _GloveboxPainter(this.warm, this.time);
  final bool warm;
  final double time;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final box = Rect.fromLTWH(w * .14, h * .33, w * .72, h * .38);
    final rounded = RRect.fromRectAndRadius(box, const Radius.circular(22));
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = LinearGradient(
          colors: warm
              ? [const Color(0xFF394150), const Color(0xFF18212C)]
              : [const Color(0xFF28465E), const Color(0xFF122332)],
        ).createShader(box),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = warm ? TutorialColors.warm : TutorialColors.ice
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * .5, h * .42),
          width: w * .15,
          height: 11,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = TutorialColors.muted,
    );
    final ice = Paint()
      ..color = TutorialColors.ice.withValues(alpha: warm ? .10 : .65)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 12; i++) {
      final x = w * .17 + i * w * .055;
      final y = h * (.39 + .15 * math.sin(i * 4.3).abs());
      canvas.drawLine(Offset(x, y), Offset(x + 18, y + 45), ice);
      canvas.drawLine(Offset(x + 8, y + 20), Offset(x - 9, y + 27), ice);
    }
    for (int i = 0; i < 5; i++) {
      final x = w * .3 + i * w * .1;
      final path = Path()..moveTo(x, h * .23);
      for (int j = 0; j < 20; j++) {
        final y = h * .23 + j * h * .005;
        path.lineTo(x + math.sin(j * .35 + time * math.pi * 2) * 6, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = warm
              ? TutorialColors.warm.withValues(alpha: .7)
              : TutorialColors.muted.withValues(alpha: .12)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }
    _label(canvas, '조수석 송풍구', Offset(w * .5, h * .16), size: 13);
    _label(
      canvas,
      warm ? '얼음이 녹았어요' : '꽁꽁 얼어붙은 글로브박스',
      Offset(w * .5, h * .81),
      color: warm ? TutorialColors.warm : TutorialColors.ice,
      size: 18,
      weight: FontWeight.w700,
    );
    _label(
      canvas,
      warm ? '이제 수리도구를 꺼내세요' : '수리도구가 안에 있어요',
      Offset(w * .5, h * .90),
      size: 14,
    );
  }

  @override
  bool shouldRepaint(covariant _GloveboxPainter oldDelegate) => true;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({required this.time, this.clear = false, this.shelter = false});
  final double time;
  final bool clear;
  final bool shelter;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: shelter
              ? [const Color(0xFF12202D), const Color(0xFF334044)]
              : [const Color(0xFF0A1626), const Color(0xFF21394D)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(w * .78, h * .20),
      w * .05,
      Paint()
        ..color = TutorialColors.ice.withValues(alpha: .13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    for (int layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, h);
      for (int i = 0; i <= 20; i++) {
        final x = w * i / 20;
        final y =
            h * (.48 + layer * .12) + math.sin(i * .48 + layer * 2) * h * .08;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xFF253C50),
            const Color(0xFF345065),
            const Color(0xFF456175),
          ][layer].withValues(alpha: .7),
      );
    }
    for (int i = 0; i < 15; i++) {
      final x = w * ((i * .173 + .04) % 1);
      final y = h * (.49 + .14 * math.sin(i * 4.1).abs());
      final height = h * (.12 + .10 * math.sin(i * 2.1).abs());
      final path = Path()
        ..moveTo(x, y - height)
        ..lineTo(x - height * .25, y)
        ..lineTo(x + height * .25, y)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF0C2230).withValues(alpha: .65),
      );
    }
    final road = Path()
      ..moveTo(w * .60, h * .62)
      ..quadraticBezierTo(w * .37, h * .72, w * .23, h)
      ..lineTo(w * .78, h)
      ..quadraticBezierTo(w * .55, h * .78, w * .65, h * .62)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = const Color(0xFF78909D).withValues(alpha: .20),
    );
    if (clear || shelter) {
      final x = w * .62;
      final y = h * .53;
      final sw = w * (shelter ? .25 : .13);
      final sh = sw * .6;
      canvas.drawCircle(
        Offset(x, y),
        sw * .85,
        Paint()
          ..color = TutorialColors.warm.withValues(alpha: .13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - sw / 2, y - sh / 2, sw, sh),
        Paint()..color = const Color(0xFF4B3D36),
      );
      final roof = Path()
        ..moveTo(x - sw * .6, y - sh * .5)
        ..lineTo(x, y - sh * 1.3)
        ..lineTo(x + sw * .6, y - sh * .5)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFBDCFD6));
      for (final dx in [-.30, .22]) {
        canvas.drawRect(
          Rect.fromLTWH(x + sw * dx, y - sh * .2, sw * .20, sh * .36),
          Paint()..color = TutorialColors.warm,
        );
      }
      if (shelter) {
        _label(
          canvas,
          'SHELTER',
          Offset(x, y - sh * .61),
          color: const Color(0xFF102030),
          size: 10,
          weight: FontWeight.w800,
        );
      }
    }
    final random = math.Random(42);
    for (int i = 0; i < (clear ? 45 : 110); i++) {
      final x =
          ((random.nextDouble() + time * (.1 + random.nextDouble() * .1)) % 1) *
          w;
      final y =
          ((random.nextDouble() + time * (.2 + random.nextDouble() * .3)) % 1) *
          h;
      final radius = .7 + random.nextDouble() * 1.6;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Colors.white.withValues(
            alpha: .15 + random.nextDouble() * .4,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
