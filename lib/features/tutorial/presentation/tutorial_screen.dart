import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/game_audio.dart';
import '../../home/presentation/home_palette.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import '../domain/tutorial_script.dart';
import '../integration/narration_player.dart';
import '../integration/tutorial_input_source.dart';
import '../integration/pleos_tutorial_input_source.dart';
import 'tutorial_artwork.dart';
import 'tutorial_celebration.dart';
import 'tutorial_style.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.controller,
    this.narrationPlayer,
    this.inputSource,
    this.onFinished,
    this.onExit,
    this.audio,
    this.previewOnly = false,
  });

  final TutorialController? controller;
  final NarrationPlayer? narrationPlayer;
  final TutorialInputSource? inputSource;
  final ValueChanged<TutorialResult>? onFinished;

  /// Leaves the story without a result ("포기하기"). Defaults to popping
  /// this route, which returns to the home screen.
  final VoidCallback? onExit;
  final GameAudio? audio;
  final bool previewOnly;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with WidgetsBindingObserver {
  late TutorialController c;
  late final NarrationPlayer _voice;
  StreamSubscription<TutorialVehicleInput>? _subscription;
  TutorialInputSource? _source;
  int _revision = -1;
  int _speechToken = 0;
  Timer? _readingTimer;
  Completer<void>? _readingCompleter;
  bool _muted = false;
  bool _voiceUnavailable = false;
  bool _notesOpen = false;
  TutorialStage? _notesStage;
  bool _confirmingExit = false;
  bool _devOpen = false;
  TutorialStage _shownStage = TutorialStage.intro;
  final bool _gloveboxSensor = true;
  late bool _ownsController;
  int _lightReset = -1, _ambientRevision = 0;
  bool? _lightScope;
  bool _climatePrepared = false;
  Future<void> _vehicleCommands = Future.value();
  Timer? _ambientTimer;
  bool _ambientCaption = false;
  Object? _chapterCue;

  /// Developer chapter jumps: on in debug runs, off in release builds.
  /// Force either way with --dart-define=TUTORIAL_TEST_NAVIGATION=true|false.
  static const _testNavigation = bool.fromEnvironment(
    'TUTORIAL_TEST_NAVIGATION',
    defaultValue: kDebugMode,
  );
  bool get _demo => _source == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c =
        widget.controller ??
        TutorialController(
          options: TutorialOptions(waitForChapterClear: widget.audio != null),
        );
    _ownsController = widget.controller == null;
    _source =
        widget.inputSource ??
        (!widget.previewOnly &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android
            ? PleosTutorialInputSource()
            : null);
    _voice = widget.narrationPlayer ?? createFrozenNightNarration();
    c.addListener(_changed);
    if (!_demo) {
      c.enableVehicleMode();
      _listenToVehicle();
    }
  }

  void _listenToVehicle() {
    _subscription = _source!.events.listen(
      (input) => c.receive(input),
      onError: (Object error) {
        c.receive(
          TutorialVehicleInput(
            VehicleInputKind.issue,
            0,
            data: {'feature': 'connection', 'message': '$error'},
          ),
        );
        c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 0));
      },
      onDone: () =>
          c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 0)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.setBackground(state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) unawaited(_voice.stop());
    if (state == AppLifecycleState.resumed) {
      unawaited(_source?.refresh() ?? Future.value());
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.audio?.setMusic(
      c.stage == TutorialStage.intro ? GameMusic.home : GameMusic.frozenNight,
    );
    _syncVehicle();
    _syncChapterCue();
    if (_shownStage != c.stage) {
      _shownStage = c.stage;
      // Celebration sound alongside the confetti on the final screen.
      if (c.stage == TutorialStage.result) {
        unawaited(widget.audio?.playChapterClear() ?? Future.value());
      }
    }
    _closeStaleNotes();
    if (_revision != c.dialogueRevision) {
      _revision = c.dialogueRevision;
      unawaited(_playCurrent());
    }
    if (_ambientRevision != c.ambientRevision) {
      _ambientRevision = c.ambientRevision;
      unawaited(_playColdComment());
    }
  }

  void _syncChapterCue() {
    final next = c.pendingChapter;
    if (next == null || c.paused) {
      _cancelChapterCue();
      return;
    }
    if (_chapterCue != null) return;
    final token = _chapterCue = Object();
    unawaited(_playChapterCue(next, token));
  }

  Future<void> _playChapterCue(TutorialStage next, Object token) async {
    await _voice.stop();
    if (!mounted || _chapterCue != token) return;
    await widget.audio?.playChapterClear();
    if (!mounted || _chapterCue != token) return;
    _chapterCue = null;
    c.finishChapterClear(next);
  }

  void _cancelChapterCue() {
    if (_chapterCue == null) return;
    _chapterCue = null;
    widget.audio?.stopChapterClear();
  }

  void _syncVehicle() {
    if (_demo) return;
    final controller = c;
    final active =
        c.inLightPuzzle && c.connected && c.parked && !c.appInBackground;
    if (_lightScope != active) {
      _lightScope = active;
      if (!active) {
        _lightReset = -1;
        // Cancellation must not wait behind an in-flight reset request.
        unawaited(_source!.setLightPuzzleActive(false).catchError((_) {}));
      } else {
        _vehicleCommands = _vehicleCommands.catchError((_) {}).then((_) async {
          if (mounted &&
              identical(c, controller) &&
              _lightScope == true &&
              c.inLightPuzzle) {
            try {
              await _source!.setLightPuzzleActive(active);
            } catch (_) {
              if (mounted && identical(c, controller) && active) {
                c.receive(
                  const TutorialVehicleInput(
                    VehicleInputKind.issue,
                    0,
                    data: {
                      'feature': 'lightControl',
                      'message': '조명 제어 연결을 확인해 주세요.',
                    },
                  ),
                );
              }
            }
            if (mounted &&
                identical(c, controller) &&
                c.stage == TutorialStage.blackout &&
                !_climatePrepared) {
              _climatePrepared = true;
              // Models with read-only climate support can still play.
              unawaited(_source!.prepareStoryClimate().catchError((_) {}));
            }
          }
        });
      }
    }
    if (active && c.lightsResetting && _lightReset != c.lightResetRevision) {
      final revision = _lightReset = c.lightResetRevision;
      _vehicleCommands = _vehicleCommands.catchError((_) {}).then((_) async {
        if (!mounted || !identical(c, controller) || !c.inLightPuzzle) {
          return;
        }
        try {
          await _source!.resetReadingLights();
          if (mounted && identical(c, controller)) {
            c.confirmLightReset(revision, success: true);
          }
        } catch (_) {
          if (mounted && identical(c, controller)) {
            c.confirmLightReset(revision, success: false);
          }
        }
      });
    }
  }

  Future<void> _playColdComment() async {
    // Background reaction: no dialog, input lock, or story advancement.
    setState(() => _ambientCaption = true);
    _ambientTimer?.cancel();
    _ambientTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _ambientCaption = false);
    });
    if (!_muted && !c.paused) {
      final token = _speechToken;
      final success = await _voice.speak(TutorialScript.coldComment);
      if (mounted && token == _speechToken && !_muted && !c.paused) {
        setState(() => _voiceUnavailable = !success);
      }
    }
  }

  Future<void> _playCurrent() async {
    final token = ++_speechToken;
    _cancelReading();
    await _voice.stop();
    if (!mounted || token != _speechToken || !c.dialogueActive || c.paused) {
      return;
    }
    final line = c.currentLine!;
    final readingTime = Duration(
      milliseconds: math.max(2800, line.text.length * 95),
    );
    final reading = Completer<void>();
    _readingCompleter = reading;
    _readingTimer = Timer(readingTime, reading.complete);
    final success = _muted ? true : await _voice.speak(line.text);
    if (!mounted || token != _speechToken) return;
    if (!_muted && _voiceUnavailable == success) {
      setState(() => _voiceUnavailable = !success);
    }
    await reading.future;
    if (!mounted || token != _speechToken || c.paused) return;
    c.advanceDialogue();
  }

  void _cancelReading() {
    _readingTimer?.cancel();
    final reading = _readingCompleter;
    if (reading != null && !reading.isCompleted) reading.complete();
    _readingCompleter = null;
  }

  void _send(
    VehicleInputKind kind,
    num value, {
    CarSeat? seat,
    String? areaId,
  }) =>
      c.receive(TutorialVehicleInput(kind, value, seat: seat, areaId: areaId));

  void _restart() {
    _cancelChapterCue();
    widget.audio?.setMusic(GameMusic.home);
    _speechToken++;
    _cancelReading();
    unawaited(_voice.stop());
    c.removeListener(_changed);
    if (_ownsController) c.dispose();
    _ownsController = true;
    _ambientTimer?.cancel();
    _ambientCaption = false;
    _ambientRevision = 0;
    _lightReset = -1;
    _lightScope = null;
    _shownStage = TutorialStage.intro;
    c = TutorialController(
      options: TutorialOptions(
        gloveboxSensorAvailable: _gloveboxSensor,
        waitForChapterClear: widget.audio != null,
      ),
    );
    if (!_demo) {
      c.enableVehicleMode();
      unawaited(
        (_subscription?.cancel() ?? Future.value()).then((_) {
          if (mounted) _listenToVehicle();
        }),
      );
    }
    c.addListener(_changed);
    _revision = -1;
    setState(() {});
  }

  void _start() {
    _climatePrepared = false;
    if (_demo &&
        widget.controller == null &&
        c.options.gloveboxSensorAvailable != _gloveboxSensor) {
      _restart();
    }
    c.start();
  }

  /// Narration and hints open over the story while the clock keeps running.
  Future<void> _notes() async {
    if (_notesOpen) return;
    _notesOpen = true;
    final openedAt = _notesStage = c.stage;
    final stages = c.visited
        .where((stage) => TutorialScript.dialogue.containsKey(stage))
        .toList();
    final latest = stages.isEmpty
        ? <DialogueLine>[]
        : TutorialScript.dialogue[stages.last]!;
    unawaited(_replay(latest));
    if (!mounted) return;
    await _dialog<void>(
      (context) => GlassDialog(
        alignment: Alignment.center,
        maxWidth: 700,
        icon: Icons.record_voice_over_rounded,
        title: '나레이션/힌트',
        actions: [
          if (TutorialScript.hints.containsKey(c.stage))
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => FilledButton.icon(
                key: const Key('hint'),
                style: StoryButtons.sand(),
                onPressed: c.canOpenHint ? _hint : null,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 24),
                label: Text('힌트 ${c.hintLevel}/3'),
              ),
            ),
          OutlinedButton(
            style: StoryButtons.glass(),
            onPressed: () => Navigator.pop(context),
            child: const Text('이야기로 돌아가기'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final stage in stages) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  _stageTitle(stage),
                  style: const TextStyle(
                    color: TutorialColors.ice,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (final line in [
                ...TutorialScript.dialogue[stage]!,
                if (stage == TutorialStage.ventilation && c.coldCommentPlayed)
                  const DialogueLine('운전석', TutorialScript.coldComment),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassTile(
                    onTap: () => unawaited(_replay([line])),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.speaker,
                                style: const TextStyle(
                                  color: TutorialColors.warm,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                line.text,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        const GlassBadge(
                          icon: Icons.volume_up_rounded,
                          size: 44,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
    _notesOpen = false;
    if (!mounted || c.stage != openedAt) return;
    // The replay interrupted the current line; read it again and carry on.
    _speechToken++;
    await _voice.stop();
    if (mounted && c.dialogueActive && !c.paused) unawaited(_playCurrent());
  }

  /// A puzzle solved while the notes are open moves the story on; close the
  /// notes so the new chapter's narration is not hidden behind them.
  void _closeStaleNotes() {
    if (!_notesOpen || _notesStage == c.stage) return;
    _notesStage = c.stage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _notesOpen) {
        Navigator.of(context).popUntil((route) => route is! PopupRoute);
      }
    });
  }

  Future<void> _replay(List<DialogueLine> lines) async {
    final token = ++_speechToken;
    _cancelReading();
    await _voice.stop();
    for (final line in lines) {
      if (!mounted ||
          !_notesOpen ||
          token != _speechToken ||
          _muted ||
          !c.parked ||
          !c.connected ||
          c.appInBackground) {
        break;
      }
      final success = await _voice.speak(line.text);
      if (!mounted || token != _speechToken || !_notesOpen) return;
      if (!_muted && !c.appInBackground && _voiceUnavailable == success) {
        setState(() => _voiceUnavailable = !success);
      }
    }
  }

  Future<void> _hint() async {
    if (!_notesOpen || !c.canOpenHint) return;
    final currentStage = c.stage;
    final hint = TutorialScript.hints[currentStage]![c.hintLevel];
    ++_speechToken;
    unawaited(_voice.stop());
    var accepted = true;
    if (c.hintsUsed == 0) {
      accepted =
          await _dialog<bool>(
            (context) => GlassDialog(
              alignment: Alignment.center,
              icon: Icons.lightbulb_outline_rounded,
              tint: TutorialColors.warm,
              title: '힌트 ${c.hintLevel + 1} / 3',
              actions: [
                FilledButton(
                  style: StoryButtons.sand(),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('힌트 열기 · +1분'),
                ),
                OutlinedButton(
                  style: StoryButtons.glass(),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('돌아가기'),
                ),
              ],
              child: GlassTile(
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: TutorialColors.warm,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Text('힌트를 열면 최종 기록에 1분이 더해져요.')),
                    _tag('+1분', color: TutorialColors.warm),
                  ],
                ),
              ),
            ),
          ) ??
          false;
    }
    if (!mounted ||
        !accepted ||
        !_notesOpen ||
        c.stage != currentStage ||
        !c.canOpenHint) {
      return;
    }
    c.useHint(fromPausedMenu: true);
    await _dialog<void>(
      (context) => GlassDialog(
        alignment: Alignment.center,
        maxWidth: 600,
        icon: Icons.tips_and_updates_outlined,
        tint: TutorialColors.warm,
        title: '힌트 ${c.hintLevel} / 3',
        actions: [
          FilledButton(
            style: StoryButtons.sand(),
            onPressed: () => Navigator.pop(context),
            child: const Text('해볼게요'),
          ),
        ],
        child: Text(hint, style: const TextStyle(fontSize: 22, height: 1.7)),
      ),
    );
  }

  void _setMuted(bool muted) {
    if (_muted == muted) return;
    setState(() => _muted = muted);
    if (muted) {
      unawaited(_voice.stop());
    } else if (c.dialogueActive) {
      unawaited(_playCurrent());
    }
  }

  /// Music and narration voice in one place, behind the gear button.
  Future<void> _settings() async {
    final settings = widget.audio?.settings;
    await _dialog<void>(
      (context) => GlassDialog(
        icon: Icons.settings_rounded,
        title: '설정',
        actions: [
          FilledButton(
            style: StoryButtons.sand(),
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
        child: StatefulBuilder(
          builder: (context, refresh) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settings != null) ...[
                ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) => GlassTile(
                    child: Column(
                      children: [
                        _settingRow(
                          icon: Icons.music_note_rounded,
                          title: '배경음악',
                          toggle: Switch(
                            key: const Key('story-bgm'),
                            value: settings.bgmOn,
                            onChanged: (value) => settings.bgmOn = value,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const SizedBox(width: 6),
                            Icon(
                              Icons.volume_down_rounded,
                              color: settings.bgmOn
                                  ? TutorialColors.muted
                                  : TutorialColors.muted.withValues(alpha: .4),
                            ),
                            Expanded(
                              child: Slider(
                                key: const Key('story-bgm-volume'),
                                value: settings.bgmVolume,
                                divisions: 10,
                                label: '${(settings.bgmVolume * 100).round()}%',
                                onChanged: settings.bgmOn
                                    ? (value) => settings.bgmVolume = value
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: 58,
                              child: Text(
                                '${(settings.bgmVolume * 100).round()}%',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GlassTile(
                child: _settingRow(
                  icon: _muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  title: '나레이션 음성',
                  subtitle: '끄면 자막으로만 진행해요',
                  toggle: Switch(
                    key: const Key('story-voice'),
                    value: !_muted,
                    onChanged: (value) {
                      _setMuted(!value);
                      refresh(() {});
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget toggle,
  }) => Row(
    children: [
      GlassBadge(icon: icon, size: 46),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: TutorialColors.muted,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      toggle,
    ],
  );

  Future<void> _giveUp() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    final leave =
        await _dialog<bool>(
          (context) => GlassDialog(
            icon: Icons.flag_rounded,
            tint: TutorialColors.warning,
            title: '포기하고 홈으로 갈까요?',
            actions: [
              FilledButton(
                key: const Key('confirm-give-up'),
                style: StoryButtons.danger(),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('포기하기'),
              ),
              OutlinedButton(
                style: StoryButtons.glass(),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('계속하기'),
              ),
            ],
            child: const Text('지금까지의 진행과 기록은 저장되지 않아요.'),
          ),
        ) ??
        false;
    _confirmingExit = false;
    if (leave && mounted) _exit();
  }

  void _exit() {
    _speechToken++;
    unawaited(_voice.stop());
    final exit = widget.onExit;
    if (exit != null) {
      exit();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelChapterCue();
    widget.audio?.setMusic(GameMusic.home);
    _speechToken++;
    _cancelReading();
    _subscription?.cancel();
    c.removeListener(_changed);
    if (_ownsController) c.dispose();
    _ambientTimer?.cancel();
    if (!_demo) {
      unawaited(_source!.setLightPuzzleActive(false).catchError((_) {}));
    }
    unawaited(_voice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !c.playing,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && c.playing) unawaited(_giveUp());
    },
    child: GameZoom(
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => _layers(box.maxWidth < _narrowWidth),
          ),
        ),
      ),
    ),
  );

  /// Below this width the corner buttons move under the clock, so they never
  /// cover the bottom-left buttons.
  static const _narrowWidth = 720.0;

  Widget _layers(bool narrow) => Stack(
    children: [
      Positioned.fill(child: _backdrop(narrow)),
      Positioned.fill(
        child: switch (c.stage) {
          TutorialStage.intro => _intro(),
          TutorialStage.result => _result(),
          TutorialStage.blackout => _blackout(),
          TutorialStage.arrival => _arrival(),
          _ => _play(narrow),
        },
      ),
      if (c.dialogueActive &&
          c.stage != TutorialStage.blackout &&
          c.stage != TutorialStage.arrival &&
          !c.paused)
        _dialogueOverlay(),
      if (c.pendingChapter != null && !c.paused)
        const IgnorePointer(
          child: Center(
            child: Chip(
              avatar: Icon(Icons.check_rounded),
              label: Text('단계 완료'),
            ),
          ),
        ),
      if (c.paused && c.playing) _pauseOverlay(),
      if (c.playing) _clock(),
      _cornerActions(narrow),
    ],
  );

  /// Dialogs scale with the story screen.
  Future<T?> _dialog<T>(WidgetBuilder builder) => showDialog<T>(
    context: context,
    barrierColor: const Color(0x8C03070D),
    builder: (context) => GameZoom(child: builder(context)),
  );

  /// Each chapter's scene fills the screen; story screens dim a photo.
  Widget _backdrop(bool narrow) => switch (c.stage) {
    TutorialStage.blackout => const ColoredBox(color: Colors.black),
    TutorialStage.intro => _dimmed(const SnowBackdrop(), .32),
    TutorialStage.arrival => _dimmed(const SnowBackdrop(shelter: true), .4),
    TutorialStage.result => _dimmed(const SnowBackdrop(shelter: true), .5),
    _ => LayoutBuilder(
      builder: (context, box) => TutorialArtwork(
        controller: c,
        // Browser demo: instruments sit to the right of the control panel.
        contentInset: _demo && !narrow
            ? EdgeInsets.only(left: _demoPanelWidth(box.maxWidth) + 24)
            : EdgeInsets.zero,
      ),
    ),
  };

  /// Width of the on-screen car controls in browser and preview builds.
  double _demoPanelWidth(double maxWidth) =>
      math.min(maxWidth - 48, (maxWidth * .42).clamp(300.0, 360.0));

  Widget _dimmed(Widget photo, double alpha) => Stack(
    fit: StackFit.expand,
    children: [
      photo,
      ColoredBox(color: TutorialColors.background.withValues(alpha: alpha)),
    ],
  );

  /// The main action of a screen: large, Hyundai Sand, bottom left.
  Widget _sandButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.arrow_forward_rounded,
  }) => FilledButton.icon(
    key: key,
    onPressed: onPressed,
    iconAlignment: IconAlignment.end,
    style: StoryButtons.sand(
      minimumSize: const Size(260, 80),
      fontSize: 24,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
      elevation: 6,
    ),
    icon: Icon(icon, size: 30),
    label: Text(label),
  );

  Widget _intro() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TutorialScript.title,
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.5,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 22),
                    Text(
                      '눈보라 속에 멈춰 버린 자동차.\n우리에게 남은 건, 서로를 믿는 마음뿐.',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.6,
                        color: Color(0xFFD0DFE8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _sandButton(
              key: const Key('start-tutorial'),
              // While the car is not ready, the button says why.
              label: c.readyToStart
                  ? '시작하기'
                  : !c.connected
                  ? '차량 연결 중…'
                  : !c.parked
                  ? 'P단에서 시작할 수 있어요'
                  : '차량 확인 중…',
              onPressed: c.readyToStart ? _start : null,
            ),
            // Not started yet, so leaving needs no confirmation.
            if (Navigator.canPop(context))
              OutlinedButton.icon(
                key: const Key('intro-home'),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 80),
                  backgroundColor: const Color(0x99101E2C),
                  textStyle: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.home_rounded, size: 28),
                label: const Text('홈으로'),
              ),
          ],
        ),
      ],
    ),
  );

  /// Safety and status notes: an icon and readable text, never small gray.
  Widget _notice(
    IconData icon,
    String text, {
    Color color = TutorialColors.ice,
    Key? key,
  }) => Row(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: TutorialColors.text,
          ),
        ),
      ),
    ],
  );

  Widget _blackout() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('연결이 끊겼습니다', color: TutorialColors.muted),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: TutorialColors.ice,
                      size: 30,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '운전석',
                      style: TextStyle(
                        color: TutorialColors.ice,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.currentLine?.text ?? '',
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _dialogueNext(),
      ],
    ),
  );

  Widget _play(bool narrow) => LayoutBuilder(
    builder: (context, constraints) {
      const pad = 24.0;
      final panelWidth = _demoPanelWidth(constraints.maxWidth);
      final status = <Widget>[
        if (!_demo && c.feedback.isNotEmpty)
          Text(
            c.feedback,
            style: const TextStyle(
              color: TutorialColors.warm,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (_ambientCaption && c.stage == TutorialStage.ventilation)
          const Text(
            TutorialScript.coldComment,
            key: Key('cold-caption'),
            style: TextStyle(
              color: TutorialColors.ice,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (!_demo && c.vehicleIssues.isNotEmpty)
          _notice(
            Icons.link_off_rounded,
            '차량 상태를 읽지 못했어요. 연결을 확인해 주세요.',
            color: TutorialColors.warning,
          ),
      ];
      return Stack(
        children: [
          // Keeps captions and buttons readable over the full-bleed scene.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment(0, .15),
                    colors: [Color(0xB3060B12), Color(0x00060B12)],
                  ),
                ),
              ),
            ),
          ),
          // Browser and preview builds play with on-screen car controls.
          if (_demo)
            Positioned(
              left: pad,
              top: narrow ? 160 : pad,
              width: panelWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    120,
                    constraints.maxHeight - (narrow ? 160 : pad) - pad - 150,
                  ),
                ),
                child: GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(child: _taskPanel()),
                ),
              ),
            ),
          Positioned(
            left: pad,
            right: narrow ? pad : math.min(300, constraints.maxWidth * .4),
            bottom: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in status) ...[line, const SizedBox(height: 8)],
                if (status.isNotEmpty) const SizedBox(height: 6),
                _footer(),
              ],
            ),
          ),
        ],
      );
    },
  );

  /// Play time only, on floating glass in the top-right corner.
  Widget _clock() => Positioned(
    top: 20,
    right: 20,
    child: IgnorePointer(
      child: GlassPanel(
        key: const Key('story-clock'),
        width: null,
        radius: 40,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_outlined,
              color: TutorialColors.ice,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              formatTime(c.elapsed),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: TutorialColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Bottom right: give up, plus developer chapter jumps in debug runs.
  Widget _cornerActions(bool narrow) {
    final canGiveUp = c.playing && c.stage != TutorialStage.arrival;
    if (!canGiveUp && !_testNavigation) return const SizedBox.shrink();
    final dev = [
      if (_testNavigation && _devOpen) ...[
        if (narrow) const SizedBox(height: 12),
        _devPanel(),
        if (!narrow) const SizedBox(height: 12),
      ],
    ];
    return Positioned(
      right: narrow ? 20 : 24,
      top: narrow ? 84 : null,
      bottom: narrow ? null : 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!narrow) ...dev,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canGiveUp)
                OutlinedButton.icon(
                  key: const Key('give-up'),
                  onPressed: _giveUp,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 64),
                    backgroundColor: const Color(0x99101E2C),
                    textStyle: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 24),
                  label: const Text('포기하기'),
                ),
              if (canGiveUp && _testNavigation) const SizedBox(width: 10),
              if (_testNavigation)
                IconButton.filledTonal(
                  key: const Key('dev-tools'),
                  tooltip: '개발자 도구',
                  onPressed: () => setState(() => _devOpen = !_devOpen),
                  icon: Icon(
                    _devOpen ? Icons.close_rounded : Icons.developer_mode,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    minHeight: 64,
                  ),
                ),
            ],
          ),
          if (narrow) ...dev,
        ],
      ),
    );
  }

  /// Test-only chapter jumps; records from such plays are not kept.
  Widget _devPanel() => SizedBox(
    width: 230,
    child: GlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 6),
            child: Text(
              '개발자 도구 · 단계 이동',
              style: TextStyle(color: TutorialColors.muted, fontSize: 14),
            ),
          ),
          TextButton.icon(
            key: const Key('test-previous'),
            onPressed: c.stage == TutorialStage.intro
                ? null
                : () => c.testNavigate(-1),
            icon: const Icon(Icons.skip_previous),
            label: const Text('이전 단계'),
          ),
          TextButton.icon(
            key: const Key('test-next'),
            onPressed: c.stage == TutorialStage.result
                ? null
                : () => c.testNavigate(1),
            icon: const Icon(Icons.skip_next),
            label: const Text('다음 단계'),
          ),
          TextButton.icon(
            key: const Key('test-first'),
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt),
            label: const Text('처음으로'),
          ),
        ],
      ),
    ),
  );

  Widget _taskPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_demo)
        _controls()
      else
        const Text(
          '차량의 실제 버튼을 조작해 주세요.',
          style: TextStyle(
            color: TutorialColors.ice,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (c.feedback.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            c.feedback,
            key: const Key('feedback'),
            style: const TextStyle(
              color: TutorialColors.warm,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      if (c.hintLevel > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _panel(
            Text(
              '힌트 ${c.hintLevel}  ·  ${c.hintText}',
              style: const TextStyle(
                color: TutorialColors.ice,
                fontSize: 17,
                height: 1.6,
              ),
            ),
          ),
        ),
      if (c.showIdleHelp)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextButton.icon(
            onPressed: _notes,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('막혔나요? 대사를 다시 들어보세요'),
          ),
        ),
    ],
  );

  Widget _controls() => switch (c.stage) {
    TutorialStage.power => Column(
      children: [
        for (final seat in CarSeat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('light-${seat.name}'),
                onPressed: c.acceptsInput
                    ? () => _send(VehicleInputKind.cabinLight, 1, seat: seat)
                    : null,
                icon: Icon(
                  c.lights[seat]! ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: c.lights[seat]! ? TutorialColors.warm : null,
                  size: 22,
                ),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${seat.label} 실내등${c.lights[seat]! ? ' · ON' : ''}',
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    TutorialStage.glovebox => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('heater'),
          onPressed: c.acceptsInput
              ? () =>
                    _send(VehicleInputKind.passengerHeater, c.heaterOn ? 0 : 1)
              : null,
          icon: const Icon(Icons.air_rounded),
          label: Text('조수석 히터 ${c.heaterOn ? '끄기' : '켜기'}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('glovebox'),
          onPressed: c.acceptsInput
              ? () => _send(VehicleInputKind.glovebox, 1)
              : null,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('글로브박스 열기'),
        ),
      ],
    ),
    TutorialStage.ventilation => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final seat in CarSeat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    seat.shortLabel,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Text(
                  '${(c.windows[seat] ?? 0).round()}%',
                  style: const TextStyle(
                    color: TutorialColors.ice,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                _windowButton(seat, -1),
                const SizedBox(width: 5),
                _windowButton(seat, 1),
              ],
            ),
          ),
        const SizedBox(height: 8),
        for (final entry in c.doors.entries)
          OutlinedButton(
            key: Key('door-${entry.key}'),
            onPressed: c.acceptsInput
                ? () => _send(
                    VehicleInputKind.door,
                    entry.value == true ? 0 : 1,
                    areaId: entry.key,
                  )
                : null,
            child: Text(
              '${entry.key == 'REAR' ? '트렁크' : '${seatForArea(entry.key)?.shortLabel ?? entry.key} 문'} ${entry.value == true ? '닫기' : '열기'}',
            ),
          ),
      ],
    ),
    TutorialStage.escape => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('wiper'),
          onPressed: c.acceptsInput
              ? () => _send(VehicleInputKind.wiper, c.wiperOn ? 0 : 1)
              : null,
          icon: const Icon(Icons.water_drop_outlined),
          label: Text('와이퍼 ${c.wiperOn ? '끄기' : '켜기'}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('front-defroster'),
          onPressed: c.acceptsInput
              ? () => _send(
                  VehicleInputKind.frontDefroster,
                  c.defrosterOn ? 0 : 1,
                )
              : null,
          icon: const Icon(Icons.waves_rounded),
          label: Text('앞유리 성에 제거 ${c.defrosterOn ? '끄기' : '켜기'}'),
        ),
        const SizedBox(height: 14),
        Text(
          '휠 ${(c.steeringAngle ?? 0).round()}°',
          style: const TextStyle(
            color: TutorialColors.ice,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final pair in const [(-45, '왼쪽'), (0, '중앙'), (45, '오른쪽')])
              OutlinedButton(
                key: Key('steering-${pair.$1}'),
                onPressed: c.acceptsInput
                    ? () => _send(VehicleInputKind.steering, pair.$1)
                    : null,
                child: Text(pair.$2),
              ),
          ],
        ),
      ],
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _windowButton(CarSeat seat, int direction) => SizedBox(
    width: 54,
    height: 54,
    child: OutlinedButton(
      key: Key('window-${seat.name}-${direction > 0 ? 'down' : 'up'}'),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: c.acceptsInput ? () => c.moveWindow(seat, direction) : null,
      child: Semantics(
        excludeSemantics: true,
        label: '${seat.label} 창문 ${direction > 0 ? '내림' : '올림'}',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              direction > 0
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              size: 22,
            ),
            Text(
              direction > 0 ? '내림' : '올림',
              style: const TextStyle(fontSize: 12, height: 1),
            ),
          ],
        ),
      ),
    ),
  );

  /// Bottom left: narration/hints and the settings gear.
  Widget _footer() => Wrap(
    spacing: 12,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton.tonalIcon(
        key: const Key('notes'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: c.visited.isEmpty || c.pendingChapter != null
            ? null
            : _notes,
        icon: const Icon(Icons.help_outline_rounded, size: 26),
        label: const Text('나레이션/힌트'),
      ),
      IconButton.filledTonal(
        key: const Key('story-settings'),
        tooltip: '설정',
        onPressed: _settings,
        icon: const Icon(Icons.settings_rounded, size: 28),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
      ),
      if (_voiceUnavailable) _tag('음성 재생 실패 · 자막으로 진행'),
    ],
  );

  Widget _dialogueOverlay() => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: .58),
      // Bottom-left: the story text above, the big next button in the
      // corner nearest the driver.
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _panel(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: TutorialColors.ice,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            c.currentLine?.speaker ?? '',
                            style: const TextStyle(
                              color: TutorialColors.ice,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _tag('${c.dialogueIndex + 1} / ${c.dialogue.length}'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        c.currentLine?.text ?? '',
                        style: const TextStyle(fontSize: 26, height: 1.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _dialogueNext(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 64),
                    ),
                    onPressed: _notes,
                    icon: const Icon(Icons.help_outline_rounded),
                    label: const Text('나레이션/힌트'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _dialogueNext() => _sandButton(
    key: const Key('next-dialogue'),
    onPressed: () {
      _speechToken++;
      unawaited(_voice.stop());
      c.advanceDialogue();
    },
    label: c.dialogueIndex + 1 < c.dialogue.length
        ? '다음'
        : c.stage == TutorialStage.blackout
        ? '어둠 속 살펴보기'
        : c.stage == TutorialStage.arrival
        ? '결과 보기'
        : '이어서 해보기',
  );

  Widget _pauseOverlay() => Positioned.fill(
    child: ColoredBox(
      color: TutorialColors.background.withValues(alpha: .96),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  !c.parked
                      ? Icons.local_parking
                      : !c.connected
                      ? Icons.link_off
                      : Icons.pause_circle_outline,
                  size: 56,
                  color: TutorialColors.ice,
                ),
                const SizedBox(height: 20),
                Text(
                  !c.parked
                      ? 'P단에서 이야기를 이어가요'
                      : !c.connected
                      ? '차량 연결을 기다리고 있어요'
                      : c.hasSensorProblem
                      ? '차량 상태를 확인하고 있어요'
                      : '잠시 숨을 고르세요',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  !c.parked
                      ? '시간이 멈춰 있어요'
                      : !c.connected
                      ? '연결되면 같은 퍼즐에서 이어가요'
                      : c.hasSensorProblem
                      ? '연결되면 이어서 진행해요'
                      : '시간이 멈춰 있어요',
                  style: const TextStyle(
                    color: TutorialColors.text,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 26),
                if (c.parked &&
                    c.connected &&
                    c.vehicleIssues.containsKey('lightReset'))
                  FilledButton(
                    onPressed: c.retryLightReset,
                    child: const Text('조명 초기화 다시 시도'),
                  ),
                if (c.parked && c.connected && !c.hasSensorProblem)
                  FilledButton.icon(
                    key: const Key('resume'),
                    onPressed: () => c.setManualPause(false),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('이어서 하기'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _arrival() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: _panel(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eyebrow('안전한 곳에 도착했습니다', color: TutorialColors.warm),
                      const SizedBox(height: 12),
                      if (c.usedTestNavigation)
                        _tag('단계 이동을 사용한 테스트 기록', color: TutorialColors.warm),
                      Text(
                        c.currentLine?.text ?? '',
                        style: const TextStyle(fontSize: 27, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _dialogueNext(),
      ],
    ),
  );

  /// Cleared: confetti cannons, a cheer, the three numbers that matter and
  /// one way out.
  Widget _result() {
    final r = c.result!;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: .55, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) => Transform.scale(
                              scale: scale,
                              alignment: Alignment.centerLeft,
                              child: child,
                            ),
                            child: const Text(
                              '와, 축하해요!',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                                height: 1.15,
                                color: HyundaiColors.sand,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '얼어붙은 밤을 무사히 탈출했어요.',
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.5,
                              color: Color(0xFFD7E2E8),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _panel(
                            Wrap(
                              spacing: 44,
                              runSpacing: 20,
                              children: [
                                _stat('플레이 시간', formatTime(r.playTime)),
                                // Each hint adds a minute to the final record.
                                _stat(
                                  '힌트',
                                  r.hintsUsed == 0
                                      ? '0회'
                                      : '${r.hintsUsed}회 · +${r.hintsUsed}분',
                                ),
                                _stat('최종 기록', formatTime(r.recordedTime)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sandButton(
                key: const Key('go-home'),
                label: '홈 화면으로',
                icon: Icons.home_rounded,
                onPressed: () {
                  final finished = widget.onFinished;
                  if (finished != null) {
                    finished(r);
                  } else {
                    _exit();
                  }
                },
              ),
            ],
          ),
        ),
        const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TutorialColors.text,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: TutorialColors.warm,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  Widget _eyebrow(String text, {Color color = TutorialColors.ice}) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: color,
    ),
  );
  Widget _panel(Widget child) => GlassPanel(child: child);

  /// Glass pill for short facts.
  Widget _tag(String text, {Color color = TutorialColors.ice}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
    ),
  );

  String _stageTitle(TutorialStage stage) => switch (stage) {
    TutorialStage.intro || TutorialStage.blackout => '눈보라 속 정전',
    TutorialStage.power => '한밤의 정적',
    TutorialStage.glovebox => '얼어붙은 글로브박스',
    TutorialStage.ventilation => '차가운 공기, 새어 나오는 가스',
    TutorialStage.escape => '눈 너머의 불빛',
    TutorialStage.arrival || TutorialStage.result => '대피소에 도착하다',
  };
}
