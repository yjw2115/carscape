import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/game_audio.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import '../domain/tutorial_script.dart';
import '../integration/narration_player.dart';
import '../integration/tutorial_input_source.dart';
import '../integration/pleos_tutorial_input_source.dart';
import 'tutorial_artwork.dart';
import 'tutorial_style.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.controller,
    this.narrationPlayer,
    this.inputSource,
    this.onFinished,
    this.audio,
    this.previewOnly = false,
  });

  final TutorialController? controller;
  final NarrationPlayer? narrationPlayer;
  final TutorialInputSource? inputSource;
  final ValueChanged<TutorialResult>? onFinished;
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
  bool _gloveboxSensor = true;
  late bool _ownsController;
  int _lightReset = -1, _ambientRevision = 0;
  bool? _lightScope;
  bool _climatePrepared = false;
  Future<void> _vehicleCommands = Future.value();
  Timer? _ambientTimer;
  bool _ambientCaption = false;
  Object? _chapterCue;
  static const _testNavigation = bool.fromEnvironment(
    'TUTORIAL_TEST_NAVIGATION',
    defaultValue: true,
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

  Future<void> _notes() async {
    final priorPause = c.manualPause;
    _notesOpen = true;
    c.setManualPause(true);
    final stages = c.visited
        .where((stage) => TutorialScript.dialogue.containsKey(stage))
        .toList();
    final latest = stages.isEmpty
        ? <DialogueLine>[]
        : TutorialScript.dialogue[stages.last]!;
    unawaited(_replay(latest));
    if (!mounted) return;
    await _dialog<void>(
      (context) => AlertDialog(
        alignment: Alignment.center,
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: TutorialColors.ice),
            SizedBox(width: 12),
            Text('나레이션/힌트'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stage in stages) ...[
                  Text(
                    _stageTitle(stage),
                    style: const TextStyle(
                      color: TutorialColors.ice,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final line in [
                    ...TutorialScript.dialogue[stage]!,
                    if (stage == TutorialStage.ventilation &&
                        c.coldCommentPlayed)
                      const DialogueLine('운전석', TutorialScript.coldComment),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: TutorialColors.background,
                        title: Text(
                          line.speaker,
                          style: const TextStyle(
                            color: TutorialColors.warm,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          line.text,
                          style: const TextStyle(
                            fontSize: 18,
                            color: TutorialColors.text,
                            height: 1.6,
                          ),
                        ),
                        trailing: const Icon(Icons.volume_up_outlined),
                        onTap: () => unawaited(_replay([line])),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          if (TutorialScript.hints.containsKey(c.stage))
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => FilledButton.icon(
                key: const Key('hint'),
                onPressed: c.canOpenHint ? _hint : null,
                icon: const Icon(Icons.lightbulb_outline),
                label: Text('힌트 ${c.hintLevel}/3'),
              ),
            ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('이야기로 돌아가기'),
          ),
        ],
      ),
    );
    _notesOpen = false;
    _speechToken++;
    await _voice.stop();
    if (mounted) c.setManualPause(priorPause);
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
            (context) => AlertDialog(
              alignment: Alignment.center,
              title: Text('힌트 ${c.hintLevel + 1} / 3'),
              content: const Text('힌트를 열면 최종 기록에 1분이 더해져요.'),
              actionsAlignment: MainAxisAlignment.start,
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('힌트 열기 · +1분'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('돌아가기'),
                ),
              ],
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
      (context) => AlertDialog(
        alignment: Alignment.center,
        title: Text('힌트 ${c.hintLevel} / 3'),
        content: Text(hint, style: const TextStyle(fontSize: 21, height: 1.7)),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('해볼게요'),
          ),
        ],
      ),
    );
  }

  Future<void> _musicSettings() async {
    final settings = widget.audio!.settings;
    final priorPause = c.manualPause;
    _notesOpen = true;
    c.setManualPause(true);
    await _dialog<void>(
      (context) => AlertDialog(
        title: const Text('배경음악'),
        content: SizedBox(
          width: 400,
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('배경음악 켜기'),
                  value: settings.bgmOn,
                  onChanged: (value) => settings.bgmOn = value,
                ),
                Row(
                  children: [
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
                    Text('${(settings.bgmVolume * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    _notesOpen = false;
    if (mounted) c.setManualPause(priorPause);
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
      if (!didPop && c.playing) c.setManualPause(true);
    },
    child: GameZoom(
      child: Scaffold(
        bottomNavigationBar: _testNavigation ? _testToolbar() : null,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: c.stage == TutorialStage.blackout
                    ? const ColoredBox(color: Colors.black)
                    : SnowBackdrop(
                        shelter:
                            c.stage == TutorialStage.result ||
                            c.stage == TutorialStage.arrival,
                      ),
              ),
              if (c.stage != TutorialStage.blackout)
                Positioned.fill(
                  child: ColoredBox(
                    color: TutorialColors.background.withValues(
                      alpha:
                          c.stage == TutorialStage.intro ||
                              c.stage == TutorialStage.result
                          ? .32
                          : .83,
                    ),
                  ),
                ),
              Positioned.fill(
                child: switch (c.stage) {
                  TutorialStage.intro => _intro(),
                  TutorialStage.result => _result(),
                  TutorialStage.blackout => _blackout(),
                  TutorialStage.arrival => _arrival(),
                  _ => _play(),
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
              if (c.paused &&
                  c.playing &&
                  (!_notesOpen || !c.parked || !c.connected))
                _pauseOverlay(),
            ],
          ),
        ),
      ),
    ),
  );

  /// Dialogs scale with the story screen.
  Future<T?> _dialog<T>(WidgetBuilder builder) => showDialog<T>(
    context: context,
    builder: (context) => GameZoom(child: builder(context)),
  );

  Widget _intro() => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 24 : 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _eyebrow('CARSCAPE  /  STAGE 01'),
                    const SizedBox(height: 20),
                    const Text(
                      '얼어붙은 밤',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '눈보라 속에 멈춰 버린 자동차.\n우리에게 남은 건, 서로를 믿는 마음뿐.',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.6,
                        color: Color(0xFFD0DFE8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _tag('4자리 협동'),
                        _tag('네 개의 퍼즐'),
                        _tag('실패 없이 끝까지'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _introRow(Icons.hearing_rounded, '이야기에 귀 기울여요'),
                          const SizedBox(height: 16),
                          _introRow(
                            Icons.touch_app_outlined,
                            _demo ? '차량 버튼을 화면에서 체험해요' : '차 안의 실제 버튼을 사용해요',
                          ),
                          const SizedBox(height: 16),
                          _introRow(Icons.menu_book_rounded, '놓친 대사는 노트에서'),
                        ],
                      ),
                    ),
                    if (_demo) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '글로브박스 열림 감지 지원',
                          style: TextStyle(fontSize: 16),
                        ),
                        value: _gloveboxSensor,
                        onChanged: (value) =>
                            setState(() => _gloveboxSensor = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('start-tutorial'),
                      onPressed: c.readyToStart ? _start : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('이야기 시작하기'),
                    ),
                    if (!_demo) ...[
                      const SizedBox(height: 12),
                      Text(
                        !c.connected
                            ? '차량에 연결 중입니다.'
                            : !c.parked
                            ? 'P단 정차 상태를 확인해 주세요.'
                            : '차량 연결됨 · 네 단계 준비 완료',
                        style: const TextStyle(
                          color: TutorialColors.ice,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (c.vehicleIssues.isNotEmpty)
                        Text(
                          c.vehicleIssues.values.first,
                          style: const TextStyle(
                            color: TutorialColors.warning,
                            fontSize: 15,
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    _notice(
                      Icons.info_outline_rounded,
                      _demo
                          ? '체험 모드 · 실제 차량은 제어하지 않아요.\n이야기는 허구이며 실제 차량 고장 시 대처법이 아니에요.'
                          : 'P단 정차 상태에서 플레이하세요. 시작할 때 차량 상태가 바뀔 수 있어요.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _introRow(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: TutorialColors.ice, size: 26),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  /// Safety and status notes: an icon and readable text, never small gray.
  Widget _notice(
    IconData icon,
    String text, {
    Color color = TutorialColors.ice,
    Key? key,
  }) => Row(
    key: key,
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
                  const SizedBox(height: 24),
                  _dialogueNext(),
                ],
              ),
            ),
          ),
        ),
        _footer(),
      ],
    ),
  );

  Widget _play() => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 740;
      final pad = constraints.maxWidth < 600 ? 16.0 : 26.0;
      final left = _taskPanel();
      final artwork = TutorialArtwork(controller: c);
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [
            _header(narrow),
            const SizedBox(height: 16),
            Expanded(
              child: !_demo
                  ? artwork
                  : narrow
                  ? ListView(
                      children: [
                        SizedBox(height: 260, child: artwork),
                        const SizedBox(height: 16),
                        left,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: math.min(330, constraints.maxWidth * .36),
                          child: SingleChildScrollView(child: left),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: artwork),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            if (!_demo && c.feedback.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  c.feedback,
                  style: const TextStyle(
                    color: TutorialColors.warm,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_ambientCaption && c.stage == TutorialStage.ventilation)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  TutorialScript.coldComment,
                  key: Key('cold-caption'),
                  style: TextStyle(
                    color: TutorialColors.ice,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!_demo && c.vehicleIssues.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: _notice(
                  Icons.link_off_rounded,
                  '차량 상태를 읽지 못했어요. 연결을 확인해 주세요.',
                  color: TutorialColors.warning,
                ),
              ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: _footer()),
          ],
        ),
      );
    },
  );

  Widget _header(bool narrow) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('얼어붙은 밤  /  ${c.step.toString().padLeft(2, '0')} OF 04'),
            const SizedBox(height: 5),
            Text(
              _stageTitle(c.stage),
              style: TextStyle(
                fontSize: narrow ? 23 : 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatTime(c.elapsed),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: TutorialColors.ice,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          _tag(_demo ? '화면으로 차량 체험' : '차량 연결됨'),
        ],
      ),
    ],
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

  Widget _footer() => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton.tonalIcon(
        key: const Key('notes'),
        onPressed: c.visited.isEmpty || c.pendingChapter != null
            ? null
            : _notes,
        icon: const Icon(Icons.help_outline_rounded, size: 24),
        label: const Text('나레이션/힌트'),
      ),
      if (widget.audio != null)
        IconButton(
          key: const Key('story-bgm-settings'),
          tooltip: '배경음악 음량',
          onPressed: c.pendingChapter == null ? _musicSettings : null,
          icon: const Icon(Icons.music_note_rounded),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      IconButton(
        tooltip: _muted ? '음성 켜기' : '음성 끄기',
        onPressed: () {
          setState(() => _muted = !_muted);
          if (_muted) {
            unawaited(_voice.stop());
          } else if (c.dialogueActive) {
            unawaited(_playCurrent());
          }
        },
        icon: Icon(
          _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
        ),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
      IconButton(
        key: const Key('pause'),
        tooltip: '일시정지',
        onPressed: c.pendingChapter == null
            ? () => c.setManualPause(true)
            : null,
        icon: const Icon(Icons.pause_rounded),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
      if (_voiceUnavailable) _tag('음성 재생 실패 · 자막으로 진행'),
    ],
  );

  Widget _testToolbar() => SafeArea(
    top: false,
    child: Material(
      color: const Color(0xFF162433),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '테스트',
              style: TextStyle(color: TutorialColors.muted, fontSize: 12),
            ),
            TextButton.icon(
              key: const Key('test-previous'),
              onPressed: c.stage == TutorialStage.intro
                  ? null
                  : () => c.testNavigate(-1),
              icon: const Icon(Icons.skip_previous, size: 18),
              label: const Text('이전 단계'),
            ),
            TextButton.icon(
              key: const Key('test-next'),
              onPressed: c.stage == TutorialStage.result
                  ? null
                  : () => c.testNavigate(1),
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('다음 단계'),
            ),
            TextButton.icon(
              key: const Key('test-first'),
              onPressed: _restart,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('처음으로'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dialogueOverlay() => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: .62),
      // Bottom-left: the reply buttons sit on the driver's side.
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _dialogueNext(),
                      OutlinedButton.icon(
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
      ),
    ),
  );

  Widget _dialogueNext() => FilledButton.icon(
    key: const Key('next-dialogue'),
    onPressed: () {
      _speechToken++;
      unawaited(_voice.stop());
      c.advanceDialogue();
    },
    icon: const Icon(Icons.arrow_forward_rounded),
    label: Text(
      c.dialogueIndex + 1 < c.dialogue.length
          ? '다음 대사'
          : c.stage == TutorialStage.blackout
          ? '어둠 속 살펴보기'
          : c.stage == TutorialStage.arrival
          ? '결과 보기'
          : '이어서 해보기',
    ),
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

  Widget _arrival() => Stack(
    children: [
      Positioned.fill(child: const SnowBackdrop(shelter: true)),
      Positioned.fill(
        child: ColoredBox(
          color: TutorialColors.background.withValues(alpha: .4),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(32),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
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
                    const SizedBox(height: 20),
                    _dialogueNext(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _result() {
    final r = c.result!;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.ac_unit_rounded,
                      color: TutorialColors.warm,
                      size: 55,
                    ),
                    const SizedBox(height: 20),
                    _eyebrow('스테이지 1 완료', color: TutorialColors.warm),
                    if (r.usedTestNavigation) ...[
                      const SizedBox(height: 8),
                      _tag('단계 이동을 사용한 테스트 기록', color: TutorialColors.warm),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '우리 모두, 살아남았다.',
                      style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '작은 불빛 하나부터 시작된 협동.\n네 사람의 힘으로 얼어붙은 밤을 건넜어요.',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFD7E2E8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _panel(
                      Wrap(
                        spacing: 36,
                        runSpacing: 20,
                        children: [
                          _stat('플레이 시간', formatTime(r.playTime)),
                          // Each hint adds a minute to the final record.
                          _stat(
                            '사용한 힌트',
                            r.hintsUsed == 0
                                ? '0회'
                                : '${r.hintsUsed}회 · +${r.hintsUsed}분',
                          ),
                          _stat('최종 기록', formatTime(r.recordedTime)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _tag(
                      r.hintsUsed == 0
                          ? '첫 번째 탈출 · 힌트 없이 완료'
                          : '첫 번째 탈출 · 훈련 완료',
                      color: TutorialColors.warm,
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          key: const Key('restart'),
                          onPressed: widget.controller == null
                              ? _restart
                              : null,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('다시 체험하기'),
                        ),
                        if (widget.onFinished != null)
                          OutlinedButton(
                            onPressed: () => widget.onFinished!(r),
                            child: const Text('테마 선택으로'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
