import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/tutorial_controller.dart';
import 'tutorial_style.dart';

// Fictional story instruments for chapter 3. They show the game's meters,
// never real measurements of the cabin.

/// Gas reading colors: red from 70% up, then orange, yellow and green as
/// the cabin clears.
const _gasStops = <(double, Color)>[
  (0, Color(0xFF6FDB8F)),
  (12, Color(0xFF6FDB8F)),
  (32, Color(0xFFFFDA4D)),
  (52, Color(0xFFFF9B3D)),
  (70, Color(0xFFFF4E3E)),
  (100, Color(0xFFFF4E3E)),
];

Color gasColor(double level) {
  final value = level.clamp(0.0, 100.0);
  for (var i = 1; i < _gasStops.length; i++) {
    final (from, fromColor) = _gasStops[i - 1];
    final (to, toColor) = _gasStops[i];
    if (value <= to) {
      return Color.lerp(fromColor, toColor, (value - from) / (to - from))!;
    }
  }
  return _gasStops.last.$2;
}

String _gasStatus(double level) => level >= 70
    ? '위험'
    : level >= 30
    ? '주의'
    : level > .5
    ? '낮음'
    : '안전';

const _ink = Color(0xFF2B2722);

/// A gas cylinder filled from the bottom to the current reading, in the
/// reading's color, with a digital readout and a color legend beside it.
class GasGauge extends StatelessWidget {
  const GasGauge({super.key, required this.level, required this.compact});

  final double level;
  final bool compact;

  @override
  Widget build(BuildContext context) => _Housing(
    compact: compact,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: level.clamp(0.0, 100.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: '가스 농도',
            status: _gasStatus(value),
            color: gasColor(value),
            alarm: value >= 70,
            compact: compact,
          ),
          SizedBox(height: compact ? 6 : 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _GasTank(level: value)),
                SizedBox(width: compact ? 8 : 18),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: compact ? 40 : 66,
                        child: _Lcd(
                          text: '${value.round()}%',
                          color: gasColor(value),
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 16),
                        for (final (label, sample) in const [
                          ('70~100 위험', 85.0),
                          ('30~69 주의', 50.0),
                          ('1~29 낮음', 20.0),
                          ('0 안전', 0.0),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: gasColor(sample),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFB9C6CF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The cylinder itself; the gas surface sways and bubbles drift upward.
class _GasTank extends StatefulWidget {
  const _GasTank({required this.level});

  final double level;

  @override
  State<_GasTank> createState() => _GasTankState();
}

class _GasTankState extends State<_GasTank>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      key: const Key('gas-tank'),
      painter: _GasTankPainter(widget.level, _motion),
    ),
  );
}

/// Glass thermometer on an enamel card, with a digital readout beside it.
class ThermometerGauge extends StatelessWidget {
  const ThermometerGauge({
    super.key,
    required this.temperature,
    required this.compact,
  });

  final double temperature;
  final bool compact;

  @override
  Widget build(BuildContext context) => _Housing(
    compact: compact,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: temperature),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final safe = t >= TutorialController.minimumTemperature - .01;
        final tint = safe
            ? TutorialColors.success
            : t < 5
            ? const Color(0xFF7FC4FF)
            : TutorialColors.ice;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: '실내 온도',
              status: safe ? '적정' : '추움',
              color: tint,
              alarm: !safe,
              compact: compact,
            ),
            SizedBox(height: compact ? 6 : 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: CustomPaint(painter: _ThermometerPainter(t)),
                  ),
                  SizedBox(width: compact ? 8 : 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: compact ? 40 : 66,
                          child: _Lcd(
                            text: '${t.toStringAsFixed(1)}°C',
                            color: tint,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '안전 16°C 이상',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: TutorialColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Brushed-metal case with an inset, darker panel and corner screws.
class _Housing extends StatelessWidget {
  const _Housing({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF7A8690),
          Color(0xFF3B454E),
          Color(0xFF232B31),
          Color(0xFF55616B),
        ],
        stops: [0, .35, .72, 1],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 26,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Padding(
      padding: EdgeInsets.all(compact ? 3 : 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0x99000000)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF222B32), Color(0xFF10161A)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!compact)
              for (final corner in const [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: corner,
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: _Screw(),
                  ),
                ),
            Padding(
              padding: compact
                  ? const EdgeInsets.all(9)
                  : const EdgeInsets.fromLTRB(26, 16, 26, 20),
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Screw extends StatelessWidget {
  const _Screw();

  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 11,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-.4, -.4),
        colors: [Color(0xFFB8C2CA), Color(0xFF59636B), Color(0xFF2A3137)],
        stops: [0, .6, 1],
      ),
      boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 2)],
    ),
    alignment: Alignment.center,
    child: Transform.rotate(
      angle: .7,
      child: Container(width: 7, height: 1.6, color: const Color(0xFF1C2226)),
    ),
  );
}

/// Warning lamp, title and a status word in the reading's color.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.status,
    required this.color,
    required this.alarm,
    required this.compact,
  });

  final String title, status;
  final Color color;
  final bool alarm, compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Lamp(color: color, blinking: alarm),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 15 : 18,
            color: const Color(0xFFDCE4EA),
          ),
        ),
      ),
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: .16),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

/// A small indicator lamp that pulses while the reading is unsafe.
class _Lamp extends StatefulWidget {
  const _Lamp({required this.color, required this.blinking});

  final Color color;
  final bool blinking;

  @override
  State<_Lamp> createState() => _LampState();
}

class _LampState extends State<_Lamp> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  void _sync() {
    final animate = widget.blinking && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!animate) {
      _pulse.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Lamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) {
      final glow = .35 + .65 * _pulse.value;
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.35, -.35),
            colors: [
              Color.lerp(widget.color, Colors.white, .55)!,
              widget.color.withValues(alpha: .5 + .5 * glow),
            ],
          ),
          border: Border.all(color: const Color(0xCC000000)),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: .7 * glow),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    },
  );
}

/// Back-lit segment display.
class _Lcd extends StatelessWidget {
  const _Lcd({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF000000), width: 2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D1712), Color(0xFF050A08)],
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x14FFFFFF), offset: Offset(0, 1)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(color: color.withValues(alpha: .75), blurRadius: 14),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GasTankPainter extends CustomPainter {
  _GasTankPainter(this.level, this.motion) : super(repaint: motion);

  final double level;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 90) return;
    final fraction = (level / 100).clamp(0.0, 1.0);
    final tint = gasColor(level);
    final phase = motion.value * math.pi * 2;
    final scaleSpace = size.width < 150 ? 0.0 : 34.0;
    final tankW = math.min((size.width - scaleSpace) * .82, size.height * .46);
    final cx = (size.width - scaleSpace) / 2;
    final top = size.height * .2;
    final bottom = size.height - 12;
    final body = RRect.fromLTRBAndCorners(
      cx - tankW / 2,
      top,
      cx + tankW / 2,
      bottom,
      topLeft: Radius.circular(tankW * .42),
      topRight: Radius.circular(tankW * .42),
      bottomLeft: Radius.circular(tankW * .16),
      bottomRight: Radius.circular(tankW * .16),
    );

    // A colored haze around the tank while the gas is dangerous.
    if (fraction > .3) {
      canvas.drawRRect(
        body.inflate(6),
        Paint()
          ..color = tint.withValues(alpha: .22 * fraction)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Foot ring.
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - tankW * .4,
        bottom - 6,
        cx + tankW * .4,
        bottom + 8,
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF1B2126),
    );

    // Steel interior where there is no gas.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), const [
          Color(0xFF3A4651),
          Color(0xFF232C33),
        ]),
    );

    // Gas, filled from the bottom with a moving surface and bubbles.
    final inner = bottom - tankW * .05;
    final innerTop = top + tankW * .1;
    final surface = inner - (inner - innerTop) * fraction;
    canvas.save();
    canvas.clipRRect(body);
    if (fraction > .002) {
      final wave = Path()..moveTo(body.left, bottom);
      final amplitude = math.min(4.0, tankW * .025) * (fraction < .99 ? 1 : 0);
      for (var x = body.left; x <= body.right + 1; x += 4) {
        final t = (x - body.left) / tankW;
        wave.lineTo(x, surface + math.sin(t * math.pi * 3 + phase) * amplitude);
      }
      wave
        ..lineTo(body.right, bottom)
        ..close();
      canvas.drawPath(
        wave,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, surface),
            Offset(0, bottom),
            [
              Color.lerp(tint, Colors.white, .25)!.withValues(alpha: .95),
              tint.withValues(alpha: .9),
              Color.lerp(tint, Colors.black, .45)!,
            ],
            const [0, .35, 1],
          ),
      );
      // Bright line along the surface.
      final rim = Path();
      for (var x = body.left; x <= body.right + 1; x += 4) {
        final t = (x - body.left) / tankW;
        final y = surface + math.sin(t * math.pi * 3 + phase) * amplitude;
        x == body.left ? rim.moveTo(x, y) : rim.lineTo(x, y);
      }
      canvas.drawPath(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .45),
      );
      // Rising bubbles inside the gas.
      final bubble = Paint()..color = Colors.white.withValues(alpha: .28);
      for (var i = 0; i < 9; i++) {
        final seed = (i * 0.37) % 1;
        final rise = (motion.value + i / 9) % 1;
        final y = bottom - 8 - rise * (bottom - surface - 10);
        if (y < surface + 6) continue;
        final x =
            body.left +
            tankW * (.18 + .64 * seed) +
            math.sin(phase * 2 + i) * 4;
        canvas.drawCircle(Offset(x, y), 1.8 + (i % 3) * 1.2, bubble);
      }
    }
    // Cylinder shading over gas and steel alike.
    canvas.drawRect(
      body.outerRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(body.left, 0),
          Offset(body.right, 0),
          [
            Colors.black.withValues(alpha: .5),
            Colors.black.withValues(alpha: .05),
            Colors.white.withValues(alpha: .22),
            Colors.white.withValues(alpha: .04),
            Colors.black.withValues(alpha: .55),
          ],
          const [0, .2, .32, .55, 1],
        ),
    );
    // Weld seam around the shoulder.
    final seamY = top + tankW * .42;
    canvas.drawLine(
      Offset(body.left, seamY),
      Offset(body.right, seamY),
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..strokeWidth = 2,
    );
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF0B0F12),
    );

    // Neck, guard collar, brass valve and red handwheel.
    final neckW = tankW * .2;
    canvas.drawRect(
      Rect.fromLTRB(
        cx - neckW / 2,
        top - size.height * .05,
        cx + neckW / 2,
        top + 6,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - neckW / 2, 0),
          Offset(cx + neckW / 2, 0),
          const [Color(0xFF39434B), Color(0xFF8A96A0), Color(0xFF2A3238)],
          const [0, .4, 1],
        ),
    );
    final collar = RRect.fromLTRBR(
      cx - tankW * .32,
      top - size.height * .085,
      cx + tankW * .32,
      top + tankW * .06,
      Radius.circular(tankW * .06),
    );
    canvas.drawRRect(
      collar,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(collar.left, 0),
          Offset(collar.right, 0),
          const [
            Color(0xFF2E373E),
            Color(0xFF7E8A94),
            Color(0xFF4A555E),
            Color(0xFF20272C),
          ],
          const [0, .3, .6, 1],
        ),
    );
    for (final side in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * tankW * .17, collar.center.dy),
          width: tankW * .12,
          height: collar.height * .45,
        ),
        Paint()..color = const Color(0xFF0E1215),
      );
    }
    final valve = Rect.fromCenter(
      center: Offset(cx, top - size.height * .11),
      width: tankW * .22,
      height: size.height * .06,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(valve, const Radius.circular(3)),
      Paint()
        ..shader = ui.Gradient.linear(
          valve.centerLeft,
          valve.centerRight,
          const [Color(0xFF8C6A22), Color(0xFFE3C46B), Color(0xFF7A5A1A)],
          const [0, .4, 1],
        ),
    );
    final wheel = Rect.fromCenter(
      center: Offset(cx, valve.top - size.height * .02),
      width: tankW * .5,
      height: size.height * .045,
    );
    canvas.drawOval(
      wheel,
      Paint()
        ..shader = ui.Gradient.linear(
          wheel.topCenter,
          wheel.bottomCenter,
          const [Color(0xFFE5574A), Color(0xFF8E1B14)],
        ),
    );
    canvas.drawOval(
      wheel.deflate(wheel.height * .3),
      Paint()..color = const Color(0xFF5A110C),
    );

    // Level marks beside the tank.
    if (scaleSpace > 0) {
      final x = body.right + 8;
      for (var v = 0; v <= 100; v += 25) {
        final y = inner - (inner - innerTop) * v / 100;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + (v % 50 == 0 ? 10 : 6), y),
          Paint()
            ..color = const Color(0xFF8D9BA5)
            ..strokeWidth = 1.2,
        );
        if (v % 50 == 0) {
          _text(
            canvas,
            '$v',
            Offset(x + 13, y),
            size: 12,
            color: const Color(0xFFB9C6CF),
            alignLeft: true,
          );
        }
      }
      // Pointer at the current level.
      final y = surface;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(x + 8, y - 5)
          ..lineTo(x + 8, y + 5)
          ..close(),
        Paint()..color = tint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GasTankPainter oldDelegate) =>
      oldDelegate.level != level;
}

class _ThermometerPainter extends CustomPainter {
  const _ThermometerPainter(this.temperature);

  final double temperature;
  static const _min = -20.0, _max = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 90) return;
    // Enamel card.
    final card = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(14, size.width * .08)),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [Color(0xFFF3EEE3), Color(0xFFDAD1C0), Color(0xFFE9E2D4)],
          const [0, .6, 1],
        ),
    );
    canvas.drawRRect(
      card.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x66000000),
    );
    for (final y in [11.0, size.height - 11]) {
      canvas.drawCircle(
        Offset(size.width / 2, y),
        4.2,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width / 2 - 1.5, y - 1.5),
            5,
            const [Color(0xFFD9DEE2), Color(0xFF6E767C)],
          ),
      );
    }

    final tubeW = (size.width * .12).clamp(9.0, 20.0);
    final bulbR = tubeW * 1.15;
    final cx = size.width * .44;
    const top = 30.0;
    final bulbY = size.height - 24 - bulbR;
    final scaleTop = top + tubeW * .8 + 4;
    final scaleBottom = bulbY - bulbR - 8;
    if (scaleBottom - scaleTop < 30) return;
    double y(double t) =>
        scaleBottom - (t - _min) / (_max - _min) * (scaleBottom - scaleTop);

    // Comfort and freezing bands beside the tube.
    final bandRight = cx - tubeW / 2 - 7;
    canvas.drawRRect(
      RRect.fromLTRBR(
        bandRight - 5,
        y(_max),
        bandRight,
        y(TutorialController.minimumTemperature),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF3F9D62),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        bandRight - 5,
        y(0),
        bandRight,
        y(_min),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF4C88C6),
    );
    _text(canvas, '°C', Offset(bandRight - 16, top + 4), size: 13, color: _ink);

    // Graduations.
    final tickX = cx + tubeW / 2 + 5;
    final labelSize = (size.height * .036).clamp(10.0, 14.0);
    for (var t = _min.toInt(); t <= _max; t++) {
      final major = t % 10 == 0, mid = t % 5 == 0;
      canvas.drawLine(
        Offset(tickX, y(t.toDouble())),
        Offset(
          tickX +
              (major
                  ? 15
                  : mid
                  ? 10
                  : 5),
          y(t.toDouble()),
        ),
        Paint()
          ..color = _ink
          ..strokeWidth = major ? 1.6 : .8,
      );
      if (major) {
        _text(
          canvas,
          '$t',
          Offset(tickX + 18, y(t.toDouble())),
          size: labelSize,
          color: _ink,
          alignLeft: true,
        );
      }
    }
    // The 16° safe line, in green across the scale.
    final safeY = y(TutorialController.minimumTemperature);
    canvas.drawLine(
      Offset(tickX, safeY),
      Offset(tickX + 15, safeY),
      Paint()
        ..color = const Color(0xFF2F8A52)
        ..strokeWidth = 2.2,
    );

    // Glass tube and the empty bore.
    final tube = RRect.fromLTRBR(
      cx - tubeW / 2,
      top,
      cx + tubeW / 2,
      bulbY,
      Radius.circular(tubeW / 2),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - tubeW / 2, 0),
          Offset(cx + tubeW / 2, 0),
          const [
            Color(0xB3FFFFFF),
            Color(0x40FFFFFF),
            Color(0x26FFFFFF),
            Color(0x8CFFFFFF),
          ],
          const [0, .35, .7, 1],
        ),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x80847C70),
    );
    final boreW = tubeW * .38;
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - boreW / 2,
        top + tubeW * .4,
        cx + boreW / 2,
        bulbY,
        Radius.circular(boreW / 2),
      ),
      Paint()..color = const Color(0x40A69E90),
    );

    // Red liquid column and bulb.
    final level = y(temperature.clamp(_min, _max));
    final liquidPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - boreW / 2, 0),
        Offset(cx + boreW / 2, 0),
        const [
          Color(0xFF9C1C1C),
          Color(0xFFE53935),
          Color(0xFFFF8A80),
          Color(0xFFB71C1C),
        ],
        const [0, .45, .6, 1],
      );
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        cx - boreW / 2,
        level,
        cx + boreW / 2,
        bulbY,
        topLeft: Radius.circular(boreW / 2),
        topRight: Radius.circular(boreW / 2),
      ),
      liquidPaint,
    );
    canvas.drawCircle(
      Offset(cx, bulbY),
      bulbR + 1.5,
      Paint()..color = const Color(0x66847C70),
    );
    canvas.drawCircle(
      Offset(cx, bulbY),
      bulbR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - bulbR * .35, bulbY - bulbR * .35),
          bulbR * 1.4,
          const [Color(0xFFFF8A7A), Color(0xFFE53935), Color(0xFF8E1414)],
          const [0, .45, 1],
        ),
    );

    // Reflections on the glass.
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - tubeW * .38,
        top + tubeW * .5,
        cx - tubeW * .22,
        bulbY - bulbR * .7,
        Radius.circular(tubeW),
      ),
      Paint()..color = const Color(0x99FFFFFF),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - bulbR * .38, bulbY - bulbR * .42),
        width: bulbR * .5,
        height: bulbR * .32,
      ),
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) =>
      oldDelegate.temperature != temperature;
}

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  required double size,
  required Color color,
  bool alignLeft = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w700,
        fontFamily: 'NotoSansKR',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    at - Offset(alignLeft ? 0 : painter.width / 2, painter.height / 2),
  );
  painter.dispose();
}
