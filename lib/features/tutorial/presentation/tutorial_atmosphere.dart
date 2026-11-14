import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/tutorial_controller.dart';
import 'tutorial_instruments.dart';

export 'tutorial_instruments.dart' show gasColor;

const frozenNightCabin = 'assets/frozen_night/art/cabin.jpg';
const frozenNightRoad = 'assets/frozen_night/art/road.jpg';
const _frostAsset = 'assets/frozen_night/art/frost.jpg';
const _snowAsset = 'assets/frozen_night/art/windshield_snow.jpg';
const _gasAsset = 'assets/frozen_night/art/cabin_gas.png';

class VentilationDashboard extends StatelessWidget {
  const VentilationDashboard({
    super.key,
    required this.controller,
    this.contentInset = EdgeInsets.zero,
  });

  final TutorialController controller;
  final EdgeInsets contentInset;

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
      if (controller.gasLevel > 0)
        Positioned.fill(
          child: IgnorePointer(
            child: _SmokeDrift(
              key: const Key('cabin-gas-overlay'),
              fraction: (controller.gasLevel / 100).clamp(0.0, 1.0),
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
      Padding(
        padding: contentInset,
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 340 || box.maxWidth < 485;
            final padding = compact ? 12.0 : 24.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1060,
                  maxHeight: 450,
                ),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: GasGauge(
                          level: controller.gasLevel,
                          compact: compact,
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 18),
                      Expanded(
                        flex: 9,
                        child: ThermometerGauge(
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
      ),
    ],
  );
}

class _SmokeDrift extends StatefulWidget {
  const _SmokeDrift({super.key, required this.fraction});

  final double fraction;

  @override
  State<_SmokeDrift> createState() => _SmokeDriftState();
}

class _SmokeDriftState extends State<_SmokeDrift>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 17),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Shader _plumeMask(Rect bounds, Offset center, double strength) {
    // Keep a broad fade above each plume's denser core as it settles down.
    final density = strength * (widget.fraction * 3.5).clamp(0.0, 1.0);
    final ellipse =
        Matrix4.diagonal3Values(bounds.width * .96, bounds.height * 1.22, 1)
          ..setTranslationRaw(
            bounds.left + bounds.width * center.dx,
            bounds.top + bounds.height * (center.dy + 1 - widget.fraction),
            0,
          );
    return ui.Gradient.radial(
      Offset.zero,
      1,
      [
        Colors.white.withValues(alpha: density),
        Colors.white.withValues(alpha: density),
        Colors.white.withValues(alpha: density * .36),
        Colors.transparent,
      ],
      const [0, .77, .89, 1],
      TileMode.clamp,
      ellipse.storage,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _drift,
          child: Image.asset(
            _gasAsset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          builder: (context, smoke) {
            final phase = _drift.value * math.pi * 2;
            final left = math.sin(phase);
            final right = math.cos(phase + .8);
            return Stack(
              fit: StackFit.expand,
              children: [
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => _plumeMask(
                    bounds,
                    Offset(.26 + .10 * left, .99 + .04 * math.cos(phase)),
                    .62,
                  ),
                  child: Transform.translate(
                    offset: Offset(
                      left * width * .085,
                      math.cos(phase) * height * .075,
                    ),
                    child: Transform.scale(scale: 1.22, child: smoke),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => _plumeMask(
                    bounds,
                    Offset(.76 + .09 * right, 1.08 + .05 * math.sin(phase * 2)),
                    .49,
                  ),
                  child: Transform.translate(
                    offset: Offset(
                      right * width * .11,
                      math.sin(phase * 2) * height * .07,
                    ),
                    child: Transform.flip(
                      flipX: true,
                      flipY: true,
                      child: Transform.scale(scale: 1.28, child: smoke),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
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
                  child: _MeltingSnow(
                    melt: controller.melt,
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
              ),
            if (controller.defrosterOn && progress < 1)
              const IgnorePointer(child: _DefrosterGlow()),
            if (progress > 0 && progress < 1)
              CustomPaint(painter: _WiperBlades(progress)),
          ],
        ),
      ),
    );
  }
}

/// The defroster blows warm air up from the dashboard, so the snow thins
/// from the bottom edge first. It never clears the glass on its own.
class _MeltingSnow extends StatelessWidget {
  const _MeltingSnow({required this.melt, required this.child});

  final double melt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (melt <= .001) return child;
    final reach = (melt * 1.4).clamp(0.0, .7);
    return ShaderMask(
      key: const Key('melting-snow'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white.withValues(alpha: 1 - melt * 1.5),
          Colors.white.withValues(alpha: 1 - melt * .8),
          Colors.white,
        ],
        stops: [0, reach, (reach + .3).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}

class _DefrosterGlow extends StatelessWidget {
  const _DefrosterGlow();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment(0, .2),
        colors: [Color(0x38FFB46B), Color(0x00FFB46B)],
      ),
    ),
  );
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
