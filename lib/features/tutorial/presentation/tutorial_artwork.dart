import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import 'tutorial_style.dart';

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
        child: CustomPaint(
          painter: switch (c.stage) {
            TutorialStage.power => _CarPainter(c),
            TutorialStage.departure => _BeltsPainter(c),
            TutorialStage.glovebox => _GloveboxPainter(c.heaterOn, time),
            TutorialStage.windowCircuit => _CircuitPainter(c),
            _ => _SnowPainter(
              time: time,
              clear:
                  c.stage == TutorialStage.departure ||
                  c.stage == TutorialStage.arrival ||
                  c.stage == TutorialStage.result,
              shelter:
                  c.stage == TutorialStage.arrival ||
                  c.stage == TutorialStage.result,
              windshield: c.stage == TutorialStage.wipers,
            ),
          },
          child: const SizedBox.expand(),
        ),
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
      Offset(295, 160),
      Offset(195, 160),
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
      final connected = c.stage == TutorialStage.departure
          ? c.belts[areaForSeat(seat)] == true
          : c.lights[seat]!;
      final color = c.stage == TutorialStage.departure
          ? TutorialColors.success
          : TutorialColors.warm;
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
              ? Color.lerp(const Color(0xFF112638), color, .14)!
              : const Color(0xFF112638),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..color = connected ? color : TutorialColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (c.stage == TutorialStage.departure) {
        canvas.drawCircle(
          p.translate(0, -10),
          7,
          Paint()..color = connected ? color : TutorialColors.muted,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p.translate(0, 11), width: 23, height: 22),
            const Radius.circular(7),
          ),
          Paint()
            ..color = connected
                ? color.withValues(alpha: .5)
                : TutorialColors.border,
        );
        if (connected) {
          canvas.drawLine(
            p.translate(-15, -5),
            p.translate(15, 20),
            Paint()
              ..color = color
              ..strokeWidth = 3,
          );
        }
      } else {
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
      }
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
        c.stage == TutorialStage.departure
            ? (connected ? '연결됨' : '미연결')
            : (connected ? 'ON' : 'OFF'),
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

class _BeltsPainter extends CustomPainter {
  _BeltsPainter(this.c);
  final TutorialController c;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 490, size.height / 400);
    canvas.save();
    canvas.translate(
      (size.width - 490 * scale) / 2,
      (size.height - 400 * scale) / 2,
    );
    canvas.scale(scale);
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(85, 22, 320, 340),
      const Radius.circular(42),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF102436));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = TutorialColors.ice.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _label(
      canvas,
      '차량 앞쪽 ↑',
      const Offset(245, 42),
      color: TutorialColors.ice,
      size: 12,
    );
    if (c.beltSeats.isEmpty) {
      _label(canvas, '좌석 상태 확인 중', const Offset(245, 200));
    }
    final rows = c.beltSeats.map((s) => s.row).toSet().toList()..sort();
    for (final seat in c.beltSeats) {
      final row = rows.indexOf(seat.row);
      final x = 150.0 + seat.column * 95;
      final y = rows.length <= 2 ? 120.0 + row * 130 : 103.0 + row * 90;
      final value = c.belts[seat.id];
      final color = value == true
          ? TutorialColors.success
          : value == false
          ? TutorialColors.warning
          : TutorialColors.muted;
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 63, height: 61),
        const Radius.circular(13),
      );
      canvas.drawRRect(box, Paint()..color = color.withValues(alpha: .08));
      canvas.drawRRect(
        box,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(x, y - 12), 7, Paint()..color = color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 12, y - 2, 24, 23),
          const Radius.circular(6),
        ),
        Paint()..color = color.withValues(alpha: .4),
      );
      if (value == true) {
        canvas.drawLine(
          Offset(x - 18, y - 12),
          Offset(x + 18, y + 24),
          Paint()
            ..color = color
            ..strokeWidth = 3,
        );
      }
      _label(canvas, seat.label, Offset(x, y + 43), color: color, size: 11);
      _label(
        canvas,
        value == true
            ? '연결됨'
            : value == false
            ? '미연결'
            : '감지 대기',
        Offset(x, y + 60),
        color: color,
        size: 10,
      );
    }
    _label(
      canvas,
      '${c.buckledCount} / ${c.beltSeats.length} 좌석 연결',
      const Offset(245, 381),
      color: TutorialColors.success,
      size: 16,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeltsPainter oldDelegate) => true;
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

class _CircuitPainter extends CustomPainter {
  _CircuitPainter(this.c);
  final TutorialController c;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Include every reachable endpoint (-1..6), even at the travel limits.
    double rowY(num row) => h * .26 + row * h * .08;
    final gridPaint = Paint()
      ..color = TutorialColors.ice.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (int row = -1; row <= 6; row++) {
      canvas.drawLine(
        Offset(w * .05, rowY(row)),
        Offset(w * .95, rowY(row)),
        gridPaint,
      );
    }
    _label(
      canvas,
      'WINDOW CIRCUIT',
      Offset(w * .5, h * .07),
      color: TutorialColors.ice,
      size: 13,
    );
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(w * .04, rowY(2)),
      Offset(w * .13, rowY(2)),
      wire..color = TutorialColors.warm,
    );
    canvas.drawCircle(
      Offset(w * .04, rowY(2)),
      7,
      Paint()..color = TutorialColors.warm,
    );
    for (int i = 0; i < 4; i++) {
      final x = w * (.21 + i * .19);
      final inlet = TutorialController.circuitBaseIn[i] + c.circuitOffsets[i];
      final outlet = inlet + TutorialController.circuitDelta[i];
      final color = TutorialColors.seatColors[i];
      final rail = Rect.fromLTWH(x - w * .06, h * .14, w * .12, h * .69);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rail, const Radius.circular(10)),
        Paint()..color = color.withValues(alpha: .045),
      );
      canvas.drawLine(
        Offset(x, h * .15),
        Offset(x, h * .80),
        Paint()
          ..color = color.withValues(alpha: .16)
          ..strokeWidth = 1,
      );
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, h * .14, w, h * .69));
      final path = Path()
        ..moveTo(x - w * .075, rowY(inlet))
        ..lineTo(x, rowY(inlet))
        ..lineTo(x, rowY(outlet))
        ..lineTo(x + w * .075, rowY(outlet));
      if (i < c.connectedGates) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: .28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
      canvas.drawPath(path, wire..color = color);
      canvas.drawCircle(
        Offset(x - w * .075, rowY(inlet)),
        5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(x + w * .075, rowY(outlet)),
        5,
        Paint()..color = color,
      );
      if (i < 3) {
        canvas.drawLine(
          Offset(x + w * .075, rowY(outlet)),
          Offset(x + w * .115, rowY(outlet)),
          wire..color = i < c.connectedGates ? color : TutorialColors.border,
        );
      }
      canvas.restore();
      _label(
        canvas,
        CarSeat.values[i].shortLabel,
        Offset(x, h * .89),
        color: color,
        size: 12,
      );
    }
    canvas.drawLine(
      Offset(w * .855, rowY(2)),
      Offset(w * .96, rowY(2)),
      wire..color = TutorialColors.ice.withValues(alpha: .4),
    );
    canvas.drawCircle(
      Offset(w * .96, rowY(2)),
      8,
      Paint()..color = TutorialColors.ice,
    );
    _label(
      canvas,
      '출구',
      Offset(w * .955, rowY(2) + 25),
      color: TutorialColors.ice,
      size: 11,
    );
    _label(
      canvas,
      '전류 연결 ${c.connectedGates} / 4',
      Offset(w * .5, h * .96),
      color: TutorialColors.warm,
      size: 13,
    );
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => true;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.time,
    this.clear = false,
    this.shelter = false,
    this.windshield = false,
  });
  final double time;
  final bool clear;
  final bool shelter;
  final bool windshield;
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
    if (windshield) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFB5CBDA).withValues(alpha: .30),
      );
      for (int i = 0; i < 9; i++) {
        canvas.drawCircle(
          Offset(w * ((i * .24) % 1), h * ((i * .37) % 1)),
          w * .16,
          Paint()
            ..color = const Color(0xFFD7E2EA).withValues(alpha: .18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
      canvas.drawLine(
        Offset(w * .48, h * .95),
        Offset(w * .12, h * .67),
        Paint()
          ..color = const Color(0xFF0B1620)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(w * .75, h * .95),
        Offset(w * .40, h * .67),
        Paint()
          ..color = const Color(0xFF0B1620)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      _label(
        canvas,
        '눈 때문에 앞이 보이지 않아요',
        Offset(w * .5, h * .30),
        color: Colors.white,
        size: 18,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
