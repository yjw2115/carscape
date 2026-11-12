import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/tutorial_controller.dart';
import 'tutorial_style.dart';

const frozenNightCabin = 'assets/frozen_night/art/cabin.jpg';
const frozenNightRoad = 'assets/frozen_night/art/road.jpg';
const _frostAsset = 'assets/frozen_night/art/frost.jpg';
const _snowAsset = 'assets/frozen_night/art/windshield_snow.jpg';

class VentilationDashboard extends StatelessWidget {
  const VentilationDashboard({super.key, required this.controller});

  final TutorialController controller;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF14232D)),
      Image.asset(
        frozenNightCabin,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x83112330), Color(0xD90C1821)],
          ),
        ),
      ),
      if (controller.frost > .001)
        Positioned.fill(
          child: Opacity(
            opacity: controller.frost * .91,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                radius: .72,
                colors: [Colors.transparent, Color(0x29FFFFFF), Colors.white],
                stops: [0, .42, 1],
              ).createShader(rect),
              child: Image.asset(
                _frostAsset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, _) => frame == null
                    ? const ColoredBox(color: Color(0xFFAEC4D1))
                    : child,
              ),
            ),
          ),
        ),
      LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxHeight < 340 || box.maxWidth < 485;
          final padding = compact ? 12.0 : 24.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 390),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _GasInstrument(
                        level: controller.gasLevel,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: compact ? 10 : 18),
                    Expanded(
                      flex: 5,
                      child: _TemperatureInstrument(
                        temperature: controller.cabinTemperature,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _InstrumentShell extends StatelessWidget {
  const _InstrumentShell({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF42515C), Color(0xFF25323D), Color(0xFF151E24)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF697C88), width: 1),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 6)),
      ],
    ),
    child: Padding(padding: EdgeInsets.all(compact ? 9 : 14), child: child),
  );
}

class _GasInstrument extends StatelessWidget {
  const _GasInstrument({required this.level, required this.compact});

  final double level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final safe = level <= .01;
    final percent = level.clamp(0.0, 100.0) / 100;
    final tint = safe
        ? TutorialColors.success
        : Color.lerp(
            const Color(0xFFFFCA75),
            const Color(0xFFFF906E),
            percent,
          )!;
    return _InstrumentShell(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                safe ? Icons.verified_outlined : Icons.warning_amber_rounded,
                color: tint,
                size: compact ? 18 : 24,
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  '가스 농도',
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF243331), Color(0xFF101A1D)],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF0A1218), width: 2),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 14,
                  vertical: 7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${level.round()}%',
                            style: TextStyle(
                              color: tint,
                              fontSize: compact ? 41 : 76,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: compact ? 11 : 15,
                      child: Row(
                        children: List.generate(
                          12,
                          (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i == 0
                                    ? TutorialColors.success
                                    : percent >= i / 12
                                    ? tint
                                    : const Color(0xFF31424B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '안전 0%',
                      style: TextStyle(
                        color: TutorialColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureInstrument extends StatelessWidget {
  const _TemperatureInstrument({
    required this.temperature,
    required this.compact,
  });

  final double temperature;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final safe = temperature >= TutorialController.minimumTemperature - .01;
    final tint = safe ? TutorialColors.success : TutorialColors.ice;
    return _InstrumentShell(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '실내 온도',
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 294,
                  maxHeight: 270,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: compact ? 45 : 94,
                      height: double.infinity,
                      child: CustomPaint(
                        painter: _Thermometer(temperature, tint),
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${temperature.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  color: tint,
                                  fontSize: compact ? 29 : 43,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Text(
                            '안전 16°C 이상',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _Thermometer extends CustomPainter {
  const _Thermometer(this.temperature, this.tint);
  final double temperature;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 24) return;
    final radius = math.min(size.width * .23, size.height * .15);
    final x = size.width * .25;
    final top = 4.0;
    final bottom = size.height - radius - 3;
    final tube = Rect.fromLTRB(x - radius * .52, top, x + radius * .52, bottom);
    final glass = RRect.fromRectAndRadius(tube, Radius.circular(radius));
    final fraction = ((temperature + 20) / 40).clamp(0.0, 1.0);
    final fillY = bottom - fraction * tube.height;
    final bulb = Offset(x, bottom);
    canvas.drawRRect(glass, Paint()..color = const Color(0xFF0D1721));
    canvas.drawCircle(bulb, radius, Paint()..color = const Color(0xFF0D1721));
    canvas.save();
    canvas.clipRRect(glass);
    canvas.drawRect(
      Rect.fromLTRB(tube.left, fillY, tube.right, bottom),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            tint.withValues(alpha: .67),
            tint,
            tint.withValues(alpha: .78),
          ],
          stops: const [0, .40, 1],
        ).createShader(tube),
    );
    canvas.restore();
    canvas.drawRRect(
      glass,
      Paint()
        ..color = const Color(0xFF8297A6)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(bulb, radius * .73, Paint()..color = tint);
    for (var i = 0; i <= 10; i++) {
      final y = top + tube.height * i / 10;
      final major = i.isEven;
      canvas.drawLine(
        Offset(tube.right + 4, y),
        Offset(tube.right + (major ? 13 : 9), y),
        Paint()
          ..color = i <= 1 ? TutorialColors.success : const Color(0xFF98ACB9)
          ..strokeWidth = major ? 1.4 : .8,
      );
      if (size.width >= 78 &&
          size.height >= 100 &&
          (i == 0 || i == 1 || i == 5 || i == 10)) {
        final scale = TextPainter(
          text: TextSpan(
            text: '${20 - 4 * i}',
            style: TextStyle(
              color: i == 1 ? TutorialColors.success : const Color(0xFFABBAC3),
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        scale.paint(canvas, Offset(tube.right + 18, y - scale.height / 2));
        scale.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Thermometer oldDelegate) =>
      oldDelegate.temperature != temperature || oldDelegate.tint != tint;
}

class EscapeView extends StatelessWidget {
  const EscapeView({super.key, required this.controller});

  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: controller.shelterVisible ? '오른쪽으로 이어지는 눈길과 대피소' : '눈이 쌓인 앞유리',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: controller.visibility),
        duration: const Duration(milliseconds: 110),
        // Keep the same scene behind the glass throughout the sweep.
        child: Image.asset(
          frozenNightRoad,
          fit: BoxFit.cover,
          alignment: const Alignment(.36, .08),
          excludeFromSemantics: true,
        ),
        builder: (context, progress, road) => Stack(
          fit: StackFit.expand,
          children: [
            road!,
            if (progress < 1)
              ClipPath(
                clipper: _RemainingSnow(progress),
                child: Opacity(
                  opacity: 1 - ((progress - .52) / .48).clamp(0.0, 1.0),
                  child: Image.asset(
                    _snowAsset,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, _) => frame == null
                        ? const ColoredBox(color: Color(0xFFC5CBD1))
                        : child,
                  ),
                ),
              ),
            if (progress > 0 && progress < 1)
              CustomPaint(painter: _WiperBlades(progress)),
          ],
        ),
      ),
    );
  }
}

const _leftStop = -math.pi + .16;
const _rightStop = -.17;

Iterable<Offset> _wiperPivots(Size size) sync* {
  yield Offset(size.width * .22, size.height * 1.13);
  yield Offset(size.width * .71, size.height * 1.13);
}

double _wiperLength(Size size) =>
    math.sqrt(size.width * size.width * .27 + size.height * size.height * .95);

double _sweptAngle(double progress) =>
    _leftStop + (_rightStop - _leftStop) * (progress / .68).clamp(0.0, 1.0);

class _RemainingSnow extends CustomClipper<Path> {
  const _RemainingSnow(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final glass = Path()..addRect(Offset.zero & size);
    if (progress <= 0) return glass;
    final radius = _wiperLength(size);
    final swept = Path();
    for (final pivot in _wiperPivots(size)) {
      swept.addPath(
        Path()
          ..moveTo(pivot.dx, pivot.dy)
          ..arcTo(
            Rect.fromCircle(center: pivot, radius: radius),
            _leftStop,
            _sweptAngle(progress) - _leftStop,
            false,
          )
          ..close(),
        Offset.zero,
      );
    }
    return Path.combine(PathOperation.difference, glass, swept);
  }

  @override
  bool shouldReclip(covariant _RemainingSnow oldClipper) =>
      oldClipper.progress != progress;
}

class _WiperBlades extends CustomPainter {
  const _WiperBlades(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = progress <= .68
        ? _sweptAngle(progress)
        : _rightStop + (_leftStop - _rightStop) * ((progress - .68) / .32);
    final vector = Offset(math.cos(angle), math.sin(angle));
    final radius = _wiperLength(size);
    final scale = (size.height / 440).clamp(.6, 1.2);
    for (final pivot in _wiperPivots(size)) {
      final handle = pivot + vector * radius * .46;
      final tip = pivot + vector * radius;
      canvas.drawLine(
        pivot,
        handle,
        Paint()
          ..color = const Color(0xFF1E282E)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4 * scale,
      );
      canvas.drawLine(
        handle,
        tip,
        Paint()
          ..color = const Color(0xFF10191F)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9 * scale,
      );
      canvas.drawLine(
        handle,
        tip,
        Paint()
          ..color = const Color(0xFF485963)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WiperBlades oldDelegate) =>
      oldDelegate.progress != progress;
}
