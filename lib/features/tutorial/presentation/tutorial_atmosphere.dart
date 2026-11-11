import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import 'tutorial_style.dart';

class VentilationDashboard extends StatelessWidget {
  const VentilationDashboard({super.key, required this.controller});
  final TutorialController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _GasMistPainter(c.gasLevel)),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < 380 || box.maxWidth < 450;
              return Padding(
                padding: EdgeInsets.all(compact ? 12 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CABIN MONITOR',
                      style: TextStyle(
                        color: TutorialColors.ice.withValues(alpha: .75),
                        fontSize: compact ? 10 : 12,
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _Meter(
                            label: '가스 농도',
                            value: c.gasLevel,
                            unit: '%',
                            fraction: c.gasLevel / 100,
                            safe: c.gasLevel <= .01,
                            compact: compact,
                            isGas: true,
                          ),
                        ),
                        SizedBox(width: compact ? 24 : 48),
                        Expanded(
                          flex: 5,
                          child: _Meter(
                            label: '실내 온도',
                            value: c.cabinTemperature,
                            unit: '°C',
                            fraction: ((c.cabinTemperature + 20) / 40).clamp(
                              0.0,
                              1.0,
                            ),
                            safe:
                                c.cabinTemperature >=
                                TutorialController.minimumTemperature,
                            compact: compact,
                            isGas: false,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        for (final seat in CarSeat.values)
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.window,
                                  size: compact ? 18 : 24,
                                  color: c.windows[seat] == null
                                      ? TutorialColors.muted
                                      : TutorialColors.ice,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  seat.shortLabel,
                                  style: TextStyle(
                                    fontSize: compact ? 10 : 12,
                                    color: TutorialColors.muted,
                                  ),
                                ),
                                Text(
                                  c.windows[seat] == null
                                      ? '—'
                                      : '${c.windows[seat]!.round()}%',
                                  style: TextStyle(
                                    fontSize: compact ? 14 : 20,
                                    color: TutorialColors.ice,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final entry in c.doors.entries.where(
                          (e) => e.value != false,
                        ))
                          Text(
                            '${entry.key == 'REAR' ? '트렁크' : seatForArea(entry.key)?.shortLabel ?? entry.key} ${entry.value == null ? '감지 대기' : '열림'}',
                            style: const TextStyle(
                              color: TutorialColors.warning,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (c.frost > .001)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(opacity: c.frost * .88, child: const IceTexture()),
            ),
          ),
      ],
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.unit,
    required this.fraction,
    required this.safe,
    required this.compact,
    required this.isGas,
  });
  final String label, unit;
  final double value, fraction;
  final bool safe, compact, isGas;
  @override
  Widget build(BuildContext context) {
    final color = safe
        ? TutorialColors.success
        : isGas
        ? const Color(0xFFFF7979)
        : TutorialColors.ice;
    return Semantics(
      label: '$label ${value.toStringAsFixed(1)}$unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 15 : 19,
              color: TutorialColors.text,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.toStringAsFixed(isGas ? 0 : 1),
                  style: TextStyle(
                    fontSize: compact ? 42 : 70,
                    fontWeight: FontWeight.w300,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(fontSize: compact ? 16 : 24, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 16,
            child: CustomPaint(
              painter: _MeterTrack(fraction, isGas, color),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGas ? '0%  안전' : '16°C 이상  안전',
            style: TextStyle(
              color: TutorialColors.success,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterTrack extends CustomPainter {
  _MeterTrack(this.fraction, this.gas, this.color);
  final double fraction;
  final bool gas;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF243543),
    );
    final safe = gas
        ? Rect.fromLTWH(0, 0, size.width * .045, size.height)
        : Rect.fromLTWH(size.width * .9, 0, size.width * .1, size.height);
    canvas.drawRect(
      safe,
      Paint()..color = TutorialColors.success.withValues(alpha: .6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          3,
          size.width * fraction.clamp(0.0, 1.0),
          size.height - 6,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = color.withValues(alpha: .85),
    );
    final x = size.width * fraction.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _MeterTrack old) =>
      old.fraction != fraction || old.color != color;
}

class _GasMistPainter extends CustomPainter {
  _GasMistPainter(this.level);
  final double level;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162D37), Color(0xFF09151F)],
        ).createShader(Offset.zero & size),
    );
    final random = math.Random(27);
    for (int i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        size.width * (.08 + random.nextDouble() * .15),
        Paint()
          ..color = const Color(0xFF8D6F47).withValues(alpha: .07 * level / 100)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GasMistPainter old) => old.level != level;
}

/// Static crystalline glass, cached by a repaint boundary while opacity changes.
class IceTexture extends StatelessWidget {
  const IceTexture({super.key});
  @override
  Widget build(BuildContext context) => const RepaintBoundary(
    child: CustomPaint(painter: _IceTexturePainter(), child: SizedBox.expand()),
  );
}

class _IceTexturePainter extends CustomPainter {
  const _IceTexturePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5EDF0), Color(0xFFBBCFD9), Color(0xFFE4EDF0)],
        ).createShader(rect),
    );
    final random = math.Random(185);
    final scale = math.min(size.width, size.height);
    for (int i = 0; i < 125; i++) {
      final base = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final angle = random.nextDouble() * math.pi * 2;
      final length = scale * (.07 + random.nextDouble() * .22);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-direction.dy, direction.dx);
      final pen = Paint()
        ..color = Colors.white.withValues(alpha: .42 + random.nextDouble() * .4)
        ..strokeWidth = .7 + random.nextDouble() * 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(base, base + direction * length, pen);
      for (int j = 1; j < 12; j++) {
        final part = j / 12;
        final joint = base + direction * (length * part);
        final branch = length * (1 - part) * .42;
        for (final side in [-1.0, 1.0]) {
          final tip =
              joint + direction * (branch * .65) + normal * (branch * side);
          canvas.drawLine(joint, tip, pen);
          for (int k = 1; k < 4; k++) {
            final twig = Offset.lerp(joint, tip, k / 4)!;
            canvas.drawLine(
              twig,
              twig + direction * (branch * .2) + normal * (branch * .18 * side),
              pen..strokeWidth = .6,
            );
          }
        }
      }
    }
    // Granular packed snow along the lower edge.
    for (int i = 0; i < 140; i++) {
      final x = random.nextDouble() * size.width;
      final y = size.height * (.90 + random.nextDouble() * .15);
      canvas.drawCircle(
        Offset(x, y),
        scale * (.012 + random.nextDouble() * .045),
        Paint()
          ..color = Colors.white.withValues(
            alpha: .25 + random.nextDouble() * .5,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IceTexturePainter old) => false;
}

class EscapeView extends StatelessWidget {
  const EscapeView({super.key, required this.controller, required this.time});
  final TutorialController controller;
  final double time;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _EscapeLandscape(c.shelterVisible, time)),
        ),
        if (c.visibility < 1)
          Positioned.fill(
            child: Opacity(
              opacity: (1 - c.visibility).clamp(0.0, 1.0),
              child: const IceTexture(),
            ),
          ),
        if (c.wiperOn && c.visibility < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WiperSweep(time, c.visibility)),
            ),
          ),
        if (c.shelterVisible)
          Positioned(
            right: 18,
            bottom: 18,
            child: Text(
              '대피소',
              style: TextStyle(
                color: TutorialColors.warm.withValues(alpha: .9),
                fontSize: 17,
                letterSpacing: 3,
              ),
            ),
          ),
      ],
    );
  }
}

class _EscapeLandscape extends CustomPainter {
  _EscapeLandscape(this.shelter, this.time);
  final bool shelter;
  final double time;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142C43), Color(0xFF7D9AA9)],
        ).createShader(Offset.zero & size),
    );
    final random = math.Random(49);
    for (int i = 0; i < 35; i++) {
      final x = random.nextDouble() * w;
      final ground = h * (.52 + random.nextDouble() * .26);
      final height = h * (.1 + random.nextDouble() * .29);
      final tree = Path()
        ..moveTo(x, ground - height)
        ..lineTo(x - height * .23, ground)
        ..lineTo(x + height * .23, ground)
        ..close();
      canvas.drawPath(
        tree,
        Paint()
          ..color = const Color(
            0xFF193240,
          ).withValues(alpha: .4 + random.nextDouble() * .4),
      );
    }
    final drift = Path()
      ..moveTo(0, h * .78)
      ..quadraticBezierTo(w * .4, h * .6, w, h * .76)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(drift, Paint()..color = const Color(0xFFA9BDC8));
    final road = Path()
      ..moveTo(w * .45, h)
      ..quadraticBezierTo(w * .55, h * .8, w * .8, h * .69)
      ..lineTo(w * .82, h * .7)
      ..quadraticBezierTo(w * .67, h * .85, w * .77, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF718E9E));
    if (shelter) {
      final x = w * .79, y = h * .59, sw = w * .23, sh = h * .2;
      canvas.drawCircle(
        Offset(x, y),
        sw * .8,
        Paint()
          ..color = TutorialColors.warm.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - sw / 2, y, sw, sh),
        Paint()..color = const Color(0xFF544138),
      );
      final roof = Path()
        ..moveTo(x - sw * .61, y)
        ..lineTo(x, y - sh * .7)
        ..lineTo(x + sw * .61, y)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFEDF1EE));
      canvas.drawRect(
        Rect.fromLTWH(x - sw * .33, y + sh * .23, sw * .2, sh * .33),
        Paint()..color = const Color(0xFFFFCE85),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + sw * .13, y + sh * .23, sw * .2, sh * .33),
        Paint()..color = const Color(0xFFFFCE85),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - sw * .08, y + sh * .47, sw * .16, sh * .53),
        Paint()..color = const Color(0xFF291F1D),
      );
    }
    for (int i = 0; i < 80; i++) {
      final x = ((random.nextDouble() + time * .3) % 1) * w,
          y = ((random.nextDouble() + time * .65) % 1) * h;
      canvas.drawCircle(
        Offset(x, y),
        .7 + random.nextDouble() * 1.6,
        Paint()
          ..color = Colors.white.withValues(
            alpha: .25 + random.nextDouble() * .5,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EscapeLandscape old) =>
      old.shelter != shelter || old.time != time;
}

class _WiperSweep extends CustomPainter {
  _WiperSweep(this.time, this.visibility);
  final double time, visibility;
  @override
  void paint(Canvas canvas, Size size) {
    final angle = -math.pi * .5 + math.sin(time * math.pi * 24) * .85;
    for (final x in [.28, .7]) {
      final start = Offset(size.width * x, size.height * 1.05);
      final end =
          start + Offset(math.cos(angle), math.sin(angle)) * size.height * .88;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xFF162D39).withValues(alpha: .7)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WiperSweep old) =>
      old.time != time || old.visibility != visibility;
}
