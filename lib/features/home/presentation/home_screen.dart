import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../tutorial/presentation/tutorial_screen.dart';
import '../../tutorial/presentation/tutorial_style.dart';
import '../domain/escape_theme.dart';
import '../integration/parking_status_source.dart';
import 'coming_soon_page.dart';
import 'glass_logo.dart';
import 'home_palette.dart';
import 'home_rail.dart';
import 'theme_carousel.dart';

/// App area measured on the Pleos Connect AVD (2560×1440 display, right of
/// the driving view). Every size on the home screen scales from this.
const homeReferenceSize = Size(1682, 1210);

/// Home: driver-side control rail on the left, theme carousel on the right.
/// Callbacks default to built-in navigation and can be replaced by the team's
/// router or by tests.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.themes = homeThemes,
    this.parkingSource,
    this.brightness,
    this.onTutorial,
    this.onMy,
    this.onSettings,
    this.onStart,
    this.openVehicleCheck,
    this.lockedReason,
  });

  /// Must not be empty.
  final List<EscapeTheme> themes;
  final ParkingStatusSource? parkingSource;

  /// Overrides the system light/dark setting.
  final Brightness? brightness;

  /// Page callbacks complete when the player comes back. Gear monitoring
  /// pauses meanwhile, so the opened page may use the vehicle bridge.
  final Future<void> Function(BuildContext context)? onTutorial;

  /// MY: 기록·순위 and badges on one page.
  final Future<void> Function(BuildContext context)? onMy;
  final Future<void> Function(BuildContext context)? onSettings;
  final Future<void> Function(BuildContext context, EscapeTheme theme)? onStart;

  /// Opens the vehicle check (E2–E5, `openVehicleCheck` in features/entry)
  /// from the rail's 기능점검 button and completes when the player comes
  /// back. Gear monitoring pauses meanwhile.
  final Future<void> Function(BuildContext context)? openVehicleCheck;

  /// Why a theme can't be played yet (shown instead of the start button), or
  /// null when it can. Asked again whenever the home rebuilds.
  final String? Function(EscapeTheme theme)? lockedReason;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final ParkingStatusSource _source =
      widget.parkingSource ?? defaultParkingStatusSource();
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  StreamSubscription<ParkingState>? _subscription;
  ParkingState _parking = ParkingState.checking;
  double _slotWidth = 1;
  int _dragOrigin = 0;

  @override
  void initState() {
    super.initState();
    _watchParking();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _position.dispose();
    super.dispose();
  }

  void _watchParking() {
    _subscription = _source.watch().listen(
      (state) {
        if (mounted) setState(() => _parking = state);
      },
      onError: (Object _) {
        if (mounted) setState(() => _parking = ParkingState.checking);
      },
    );
  }

  /// The vehicle bridge serves one listener at a time, so stop listening
  /// before another screen (such as the tutorial) starts its own session.
  /// The cancel message is sent right away and platform messages keep their
  /// order, so the next screen's listen always arrives after it.
  Future<void> _pauseParkingWhile(Future<void> Function() away) async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await away();
    if (!mounted) return;
    setState(() => _parking = ParkingState.checking);
    _watchParking();
  }

  Future<void> _open(WidgetBuilder builder) => _pauseParkingWhile(
    () => Navigator.of(context).push(MaterialPageRoute<void>(builder: builder)),
  );

  /// The app theme belongs to the entry screens, so the tutorial brings its
  /// own (same as the mode select screen does).
  Future<void> _openTutorial() => _open(
    (context) => Theme(
      data: tutorialTheme(),
      child: TutorialScreen(onFinished: (_) => Navigator.of(context).pop()),
    ),
  );

  void _animateTo(double page) => _position.animateTo(
    page,
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  void _step(int delta) => _animateTo(_position.value.roundToDouble() + delta);

  void _dragStart() {
    _position.stop();
    _dragOrigin = _position.value.round();
  }

  void _dragUpdate(double dx) => _position.value -= dx / _slotWidth;

  void _dragEnd(double velocityX) {
    final fling = -velocityX / _slotWidth * 0.25;
    final target = (_position.value + fling).round().clamp(
      _dragOrigin - 1,
      _dragOrigin + 1,
    );
    _animateTo(target.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        widget.brightness ?? MediaQuery.platformBrightnessOf(context);
    final palette = HomePalette.of(brightness);
    void comingSoon(String title, String message) => _open(
      (_) => ComingSoonPage(title: title, message: message, palette: palette),
    );

    return Theme(
      data: homeTheme(brightness),
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final s = math.min(
                constraints.maxWidth / homeReferenceSize.width,
                constraints.maxHeight / homeReferenceSize.height,
              );
              _slotWidth = ThemeCarousel.slotWidth(s);
              return Stack(
                children: [
                  Positioned.fill(
                    child: ThemeCarousel(
                      position: _position,
                      themes: widget.themes,
                      s: s,
                      originX: (32 + 252 + 32) * s,
                      palette: palette,
                      parking: _parking,
                      onSelectPage: (page) => _animateTo(page.toDouble()),
                      onStart: (theme) => widget.onStart != null
                          ? _pauseParkingWhile(
                              () => widget.onStart!(context, theme),
                            )
                          : comingSoon(theme.title, '시작 전 차량 점검 화면은 준비 중이에요.'),
                      onDragStart: _dragStart,
                      onDragUpdate: _dragUpdate,
                      onDragEnd: _dragEnd,
                      lockedReason: widget.lockedReason,
                    ),
                  ),
                  Positioned(
                    left: 32 * s,
                    top: 32 * s,
                    bottom: 32 * s,
                    child: HomeRail(
                      s: s,
                      palette: palette,
                      onTutorial: widget.onTutorial != null
                          ? () => _pauseParkingWhile(
                              () => widget.onTutorial!(context),
                            )
                          : _openTutorial,
                      onMy: widget.onMy != null
                          ? () =>
                                _pauseParkingWhile(() => widget.onMy!(context))
                          : () => comingSoon('MY', '기록·순위와 배지는 준비 중이에요.'),
                      onSettings: widget.onSettings != null
                          ? () => _pauseParkingWhile(
                              () => widget.onSettings!(context),
                            )
                          : () => comingSoon('설정', '설정 화면은 준비 중이에요.'),
                      onVehicleCheck: () => widget.openVehicleCheck != null
                          ? _pauseParkingWhile(
                              () => widget.openVehicleCheck!(context),
                            )
                          : comingSoon('기능점검', '기능점검 화면은 준비 중이에요.'),
                      onPrevious: () => _step(-1),
                      onNext: () => _step(1),
                    ),
                  ),
                  Positioned(
                    right: 32 * s,
                    top: 32 * s,
                    child: GlassLogo(s: s, palette: palette),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
