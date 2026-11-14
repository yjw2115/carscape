import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/game_audio.dart';
import 'core/game_session.dart';
import 'features/badges/badge_pages.dart';
import 'features/badges/progress.dart';
import 'features/entry/check_intro_screen.dart';
import 'features/guide/tutorial_page.dart';
import 'features/home/domain/escape_theme.dart';
import 'features/home/presentation/coming_soon_page.dart';
import 'features/home/presentation/home_palette.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/my/my_page.dart';
import 'features/records/record_store.dart';
import 'features/records/records_page.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/settings_page.dart';
import 'features/tutorial/domain/tutorial_models.dart';
import 'features/tutorial/integration/narration_player.dart';
import 'features/tutorial/presentation/tutorial_screen.dart';
import 'features/tutorial/presentation/tutorial_style.dart';
import 'vehicle/vehicle_service.dart';

/// Wires the home rail and theme cards to their pages.
class CarscapeApp extends StatefulWidget {
  const CarscapeApp({
    super.key,
    required this.vehicle,
    required this.session,
    required this.records,
    required this.settings,
    required this.progress,
  });

  final VehicleService vehicle;
  final GameSession session;
  final RecordStore records;
  final AppSettings settings;
  final Progress progress;

  @override
  State<CarscapeApp> createState() => _CarscapeAppState();
}

class _CarscapeAppState extends State<CarscapeApp> with WidgetsBindingObserver {
  late final _audio = GameAudio(widget.settings);
  VehicleService get vehicle => widget.vehicle;
  GameSession get session => widget.session;
  RecordStore get records => widget.records;
  AppSettings get settings => widget.settings;
  Progress get progress => widget.progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.refreshMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audio.setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<T?> _push<T>(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: builder));

  Future<void> _check(BuildContext context) =>
      openVehicleCheck(context, vehicle, session);

  /// The vehicle check runs first, once, the natural way into the game.
  Future<void> _tutorial(BuildContext context) async {
    if (session.devices.isEmpty) await _check(context);
    if (context.mounted) {
      await _push<void>(
        context,
        (_) => TutorialPage(
          vehicle: vehicle,
          session: session,
          progress: progress,
          speak: systemSpeaker(volume: settings.narrationVolume),
        ),
      );
    }
  }

  Future<void> _start(BuildContext context, EscapeTheme theme) async {
    if (theme.id != storyFrozenNight) {
      await _push<void>(
        context,
        (c) => ComingSoonPage(
          title: theme.title,
          message: '이 스토리는 준비 중이에요.',
          palette: HomePalette.of(MediaQuery.platformBrightnessOf(c)),
        ),
      );
      return;
    }
    final result = await _push<TutorialResult>(
      context,
      (c) => Theme(
        data: tutorialTheme(),
        child: TutorialScreen(
          audio: _audio,
          narrationPlayer: createFrozenNightNarration(
            volume: settings.narrationVolume,
          ),
          onFinished: (r) => Navigator.of(c).pop(r),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    // Any finished play opens the next stories; badges and records need a
    // real play without the test-only chapter jumps.
    await progress.markCleared(theme.id);
    if (!context.mounted) return;
    if (result.usedTestNavigation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단계 이동을 사용한 플레이는 기록과 배지에 남지 않아요')),
      );
      return;
    }
    final tier = tierFor(result, storyTimeLimits[theme.id]);
    if (await progress.award(theme.id, tier) && context.mounted) {
      await _push<void>(
        context,
        (_) => BadgeGetPage(id: theme.id, name: theme.title, tier: tier),
      );
    }
    if (!context.mounted) return;
    // "홈 화면으로": after the badge and the team record, stay on home.
    await saveRecordDialog(context, records, theme.id, result);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Carscape',
    debugShowCheckedModeBanner: false,
    theme: homeTheme(Brightness.light),
    darkTheme: homeTheme(Brightness.dark),
    builder: (_, child) => kIsWeb
        ? Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _audio.refreshMusic(),
            child: child,
          )
        : child!,
    home: HomeScreen(
      openVehicleCheck: _check,
      onTutorial: _tutorial,
      onMy: (c) =>
          _push<void>(c, (_) => MyPage(records: records, progress: progress)),
      onSettings: (c) => _push<void>(
        c,
        (_) => SettingsPage(settings: settings, records: records),
      ),
      onStart: _start,
      lockedReason: (theme) => progress.lockedReason(theme.id),
    ),
  );
}
