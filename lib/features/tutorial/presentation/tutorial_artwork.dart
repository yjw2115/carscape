import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import 'tutorial_atmosphere.dart';

class TutorialArtwork extends StatelessWidget {
  const TutorialArtwork({
    super.key,
    required this.controller,
    this.contentInset = EdgeInsets.zero,
  });

  final TutorialController controller;

  /// Keeps instruments clear of overlays such as the browser demo controls;
  /// the photo itself still fills the screen.
  final EdgeInsets contentInset;

  /// Full-bleed: each chapter's scene fills the whole story screen.
  @override
  Widget build(BuildContext context) => switch (controller.stage) {
    TutorialStage.power => _Blueprint(controller: controller),
    TutorialStage.glovebox => _ColdCabin(warm: controller.heaterOn),
    TutorialStage.ventilation => VentilationDashboard(
      controller: controller,
      contentInset: contentInset,
    ),
    TutorialStage.escape => EscapeView(controller: controller),
    _ => const SnowBackdrop(shelter: true),
  };
}

class SnowBackdrop extends StatelessWidget {
  const SnowBackdrop({super.key, this.shelter = false});

  final bool shelter;

  @override
  Widget build(BuildContext context) => Image.asset(
    shelter ? frozenNightRoad : frozenNightCabin,
    fit: BoxFit.cover,
    alignment: shelter ? const Alignment(.36, .08) : Alignment.center,
    excludeFromSemantics: true,
  );
}

class _Blueprint extends StatelessWidget {
  const _Blueprint({required this.controller});

  final TutorialController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '좌석 사이를 지나는 선이 그려진 차량 설계도',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final sheetWidth = math.min(size.width - 12, size.height * 1.45);
        final drawingHeight = math.min(size.height - 26, sheetWidth * .84);
        final drawing = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: drawingHeight * 2 / 3,
          height: drawingHeight,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF151E24)),
            Center(
              child: Container(
                width: sheetWidth,
                height: size.height - 10,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFAA9274),
                      Color(0xFFE8DECA),
                      Color(0xFFE8DECA),
                      Color(0xFFE3D7BF),
                      Color(0xFFA48B6D),
                    ],
                    stops: [0, .035, .68, .96, 1],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fromRect(
              rect: drawing,
              child: Image.asset(
                'assets/frozen_night/art/blueprint.jpg',
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
            CustomPaint(
              painter: _CircuitOverlay(
                drawing: drawing,
                sheetWidth: sheetWidth,
                connected: controller.powerCount,
              ),
            ),
            IgnorePointer(
              child: CustomPaint(painter: _FlashlightShade(drawing)),
            ),
          ],
        );
      },
    ),
  );
}

class _FlashlightShade extends CustomPainter {
  const _FlashlightShade(this.drawing);

  final Rect drawing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = drawing.center.translate(0, drawing.height * .09);
    final radiusX = drawing.width * .84;
    final radiusY = drawing.height * .53;
    if (radiusX <= 0 || radiusY <= 0) return;
    final cover = size.longestSide * 2 / math.min(radiusX, radiusY);
    final shade = const RadialGradient(
      colors: [
        Color(0x00070B12),
        Color(0x00070B12),
        Color(0x72070B12),
        Color(0xE9070B12),
        Color(0xFF070B12),
      ],
      stops: [0, .51, .73, .94, 1],
    ).createShader(const Rect.fromLTWH(-1, -1, 2, 2));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.19);
    canvas.scale(radiusX, radiusY);
    canvas.drawRect(
      Rect.fromLTRB(-cover, -cover, cover, cover),
      Paint()..shader = shade,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlashlightShade oldDelegate) =>
      drawing != oldDelegate.drawing;
}

class _CircuitOverlay extends CustomPainter {
  const _CircuitOverlay({
    required this.drawing,
    required this.sheetWidth,
    required this.connected,
  });

  final Rect drawing;
  final double sheetWidth;
  final int connected;
  static const _ink = Color(0xFF152D48);
  static const _copper = Color(0xFFAD4C0A);

  Offset _point(double x, double y) => Offset(
    drawing.left + x * drawing.width,
    drawing.top + y * drawing.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      _point(.394, .626),
      _point(.614, .626),
      _point(.388, .453),
      _point(.618, .453),
    ];
    final battery = _point(.395, .769);
    final routes = [
      [battery, positions[0]],
      [positions[0], positions[1]],
      [
        positions[1],
        _point(.741, .626),
        _point(.741, .534),
        _point(.388, .534),
        positions[2],
      ],
      [positions[2], positions[3]],
    ];
    final sheetLeft = (size.width - sheetWidth) / 2;
    final margin = math.max(12.0, sheetWidth * .028);
    final paper = Rect.fromLTWH(sheetLeft, 5, sheetWidth, size.height - 10);
    final border = Paint()
      ..color = const Color(0xFF766446).withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper.deflate(6), const Radius.circular(4)),
      border,
    );

    final leftLabel = sheetLeft + margin;
    final rightLabel = sheetLeft + sheetWidth - margin;
    final labelsBesideDrawing = drawing.left - leftLabel >= 82;
    final small = size.width < 420;
    final labelSize = small ? 11.0 : 14.0;
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      final left = i.isEven;
      final drawingEdge = left ? drawing.left : drawing.right;
      final direction = left ? -1 : 1;
      final x = labelsBesideDrawing
          ? drawingEdge + direction * 18
          : (left ? leftLabel : rightLabel);
      final anchor = drawingEdge + direction * (labelsBesideDrawing ? 10 : 0);
      canvas.drawLine(
        Offset(anchor, p.dy),
        Offset(p.dx, p.dy),
        Paint()
          ..color = _ink.withValues(alpha: .27)
          ..strokeWidth = .8,
      );
      _text(
        canvas,
        CarSeat.values[i].shortLabel,
        Offset(x, p.dy),
        color: _ink,
        fontSize: labelSize,
        right: labelsBesideDrawing ? left : !left,
      );
    }

    for (var i = 0; i < routes.length; i++) {
      final active = i < connected;
      final path = Path()..addPolygon(routes[i], false);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF7EBD5)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = active ? _copper : _ink
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = active ? 3.5 : 2,
      );
      for (var j = 1; j < routes[i].length; j++) {
        final from = routes[i][j - 1], to = routes[i][j];
        final delta = to - from;
        if (delta.distance < 22) continue;
        final direction = delta / delta.distance;
        final normal = Offset(-direction.dy, direction.dx);
        final tip = Offset.lerp(from, to, .58)!;
        final tail = tip - direction * 5;
        canvas.drawPath(
          Path()
            ..moveTo((tail + normal * 3).dx, (tail + normal * 3).dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo((tail - normal * 3).dx, (tail - normal * 3).dy),
          Paint()
            ..color = active ? _copper : _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }

    final batteryScale = (drawing.height * .025).clamp(7.0, 14.0);
    final batteryBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: battery,
        width: batteryScale * 3.3,
        height: batteryScale * 1.7,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(batteryBody, Paint()..color = _ink);
    _text(
      canvas,
      '+   −',
      battery,
      color: const Color(0xFFF7EBD5),
      fontSize: batteryScale,
      center: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double fontSize,
    bool right = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'NotoSansKR',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      at -
          Offset(
            right
                ? painter.width
                : center
                ? painter.width / 2
                : 0,
            painter.height / 2,
          ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _CircuitOverlay oldDelegate) =>
      oldDelegate.connected != connected ||
      oldDelegate.drawing != drawing ||
      oldDelegate.sheetWidth != sheetWidth;
}

class _ColdCabin extends StatelessWidget {
  const _ColdCabin({required this.warm});
  final bool warm;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        frozenNightCabin,
        fit: BoxFit.cover,
        alignment: const Alignment(.25, .04),
        excludeFromSemantics: true,
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.34, .48),
            radius: .8,
            colors: warm
                ? [const Color(0x45FFAA49), Colors.transparent]
                : [Colors.transparent, const Color(0x5F12283B)],
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.center,
            colors: [Color(0xE00A131A), Colors.transparent],
          ),
        ),
      ),
    ],
  );
}
