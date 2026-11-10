import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/tutorial_controller.dart';
import '../domain/tutorial_models.dart';
import '../domain/tutorial_script.dart';
import '../integration/narration_player.dart';
import '../integration/tutorial_input_source.dart';
import 'tutorial_artwork.dart';
import 'tutorial_style.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.controller,
    this.narrationPlayer,
    this.inputSource,
    this.onFinished,
  });

  final TutorialController? controller;
  final NarrationPlayer? narrationPlayer;
  final TutorialInputSource? inputSource;
  final ValueChanged<TutorialResult>? onFinished;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TutorialController c;
  late final NarrationPlayer _voice;
  late final AnimationController _animation;
  StreamSubscription<TutorialVehicleInput>? _subscription;
  int _revision = -1;
  int _speechToken = 0;
  Timer? _readingTimer;
  Completer<void>? _readingCompleter;
  bool _muted = false;
  bool _voiceUnavailable = false;
  bool _notesOpen = false;
  bool _gloveboxSensor = true;
  bool get _demo => widget.inputSource == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c = widget.controller ?? TutorialController();
    _voice = widget.narrationPlayer ?? SystemNarrationPlayer();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    c.addListener(_changed);
    if (!_demo) {
      c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 0));
      c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 0));
      _subscription = widget.inputSource!.events.listen(
        c.receive,
        onError: (Object _) => c.receive(
          const TutorialVehicleInput(VehicleInputKind.connection, 0),
        ),
        onDone: () => c.receive(
          const TutorialVehicleInput(VehicleInputKind.connection, 0),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.setBackground(state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) unawaited(_voice.stop());
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_revision != c.dialogueRevision) {
      _revision = c.dialogueRevision;
      unawaited(_playCurrent());
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
    if (!success) setState(() => _voiceUnavailable = true);
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

  void _send(VehicleInputKind kind, num value, {CarSeat? seat}) =>
      c.receive(TutorialVehicleInput(kind, value, seat: seat));

  void _restart() {
    _speechToken++;
    _cancelReading();
    unawaited(_voice.stop());
    c.removeListener(_changed);
    if (widget.controller == null) c.dispose();
    c = TutorialController(
      options: TutorialOptions(gloveboxSensorAvailable: _gloveboxSensor),
    );
    c.addListener(_changed);
    _revision = -1;
    setState(() {});
  }

  void _start() {
    if (widget.controller == null &&
        c.options.gloveboxSensorAvailable != _gloveboxSensor) {
      _restart();
    }
    c.start();
  }

  Future<void> _notes() async {
    final priorPause = c.manualPause;
    c.setManualPause(true);
    _notesOpen = true;
    final stages = c.visited
        .where((stage) => TutorialScript.dialogue.containsKey(stage))
        .toList();
    final latest = stages.isEmpty
        ? <DialogueLine>[]
        : TutorialScript.dialogue[stages.last]!;
    unawaited(_replay(latest));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: TutorialColors.ice),
            SizedBox(width: 12),
            Text('나레이션 노트'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지금까지 들은 대사예요. 눌러서 다시 들을 수 있어요.',
                  style: TextStyle(color: TutorialColors.muted),
                ),
                const SizedBox(height: 16),
                for (final stage in stages) ...[
                  Text(
                    _stageTitle(stage),
                    style: const TextStyle(
                      color: TutorialColors.ice,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final line in TutorialScript.dialogue[stage]!)
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
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          line.text,
                          style: const TextStyle(
                            fontSize: 16,
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
          FilledButton(
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
      if (!success && mounted) setState(() => _voiceUnavailable = true);
    }
  }

  Future<void> _hint() async {
    if (!c.canHint || !c.acceptsInput) return;
    final currentStage = c.stage;
    final hint = TutorialScript.hints[currentStage]![c.hintLevel];
    c.setManualPause(true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('힌트 ${c.hintLevel + 1} / 3'),
        content: const Text(
          '힌트를 열면 사용 횟수가 1회 늘고, 최종 기록에 1분이 더해져요.\n나레이션 노트는 몇 번을 열어도 무료예요.',
        ),
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
    );
    if (!mounted) return;
    c.setManualPause(false);
    if (accepted != true || c.stage != currentStage) return;
    c.useHint();
    if (c.stage != currentStage) return;
    c.setManualPause(true);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('힌트 ${c.hintLevel} / 3'),
        content: Text(hint, style: const TextStyle(fontSize: 19, height: 1.7)),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('해볼게요'),
          ),
        ],
      ),
    );
    if (mounted) c.setManualPause(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechToken++;
    _cancelReading();
    _subscription?.cancel();
    c.removeListener(_changed);
    if (widget.controller == null) c.dispose();
    _animation.dispose();
    unawaited(_voice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !c.playing,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && c.playing) c.setManualPause(true);
    },
    child: Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: c.stage == TutorialStage.blackout
                    ? const ColoredBox(color: Colors.black)
                    : SnowBackdrop(
                        time: _animation.value,
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
                    _eyebrow('CARSCAPE  /  TUTORIAL 01'),
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
                        _tag('다섯 개의 퍼즐'),
                        _tag('실패 없이 끝까지'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _introRow(
                            Icons.hearing_rounded,
                            '이야기에 귀 기울여요',
                            '대사 속에 다음 행동의 단서가 숨어 있어요.',
                          ),
                          const SizedBox(height: 12),
                          _introRow(
                            Icons.touch_app_outlined,
                            _demo ? '차량 버튼을 화면에서 체험해요' : '차 안의 실제 버튼을 사용해요',
                            _demo
                                ? '실내등, 창문, 와이퍼를 화면 버튼으로 조작해요.'
                                : '차량이 P단인지 확인하고 진행해 주세요.',
                          ),
                          const SizedBox(height: 12),
                          _introRow(
                            Icons.menu_book_rounded,
                            '놓친 대사는 노트에서',
                            '다시 듣기와 자막은 언제나 무료예요.',
                          ),
                        ],
                      ),
                    ),
                    if (_demo) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '글로브박스 열림 감지 지원',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '끄면 히터 작동만으로 다음 이야기로 넘어가요.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _gloveboxSensor,
                        onChanged: (value) =>
                            setState(() => _gloveboxSensor = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('start-tutorial'),
                      onPressed: _start,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('이야기 시작하기'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _demo
                          ? '체험 모드 · 실제 차량은 제어하지 않아요.\n이야기는 허구이며 실제 차량 고장 시 대처법이 아니에요.'
                          : '정차한 차량에서만 플레이하세요. 실내등을 미리 끄면 더 실감나요.',
                      style: const TextStyle(
                        color: TutorialColors.muted,
                        fontSize: 12,
                        height: 1.6,
                      ),
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

  Widget _introRow(IconData icon, String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: TutorialColors.ice, size: 23),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: TutorialColors.muted,
                height: 1.6,
              ),
            ),
          ],
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
                    style: TextStyle(color: TutorialColors.ice, fontSize: 14),
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
      final artwork = TutorialArtwork(controller: c, time: _animation.value);
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [
            _header(narrow),
            const SizedBox(height: 16),
            Expanded(
              child: narrow
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
            _eyebrow('얼어붙은 밤  /  ${c.step.toString().padLeft(2, '0')} OF 05'),
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
              fontSize: 24,
              color: TutorialColors.ice,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            _demo ? '화면으로 차량 체험' : '차량 연결됨',
            style: const TextStyle(fontSize: 11, color: TutorialColors.muted),
          ),
        ],
      ),
    ],
  );

  Widget _taskPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('지금 할 일'),
            const SizedBox(height: 9),
            Text(
              _taskTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _taskBody,
              style: const TextStyle(
                fontSize: 14,
                color: TutorialColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_demo)
        _controls()
      else
        const Text(
          '차량의 실제 버튼을 조작해 주세요.',
          style: TextStyle(color: TutorialColors.ice),
        ),
      if (c.feedback.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            c.feedback,
            key: const Key('feedback'),
            style: const TextStyle(
              color: TutorialColors.warm,
              fontSize: 14,
              height: 1.6,
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
                fontSize: 14,
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
                  size: 19,
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
    TutorialStage.windowRequest || TutorialStage.windowCircuit => Column(
      children: [
        for (final seat in CarSeat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 31,
                  decoration: BoxDecoration(
                    color: TutorialColors.seatColors[seat.index],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    seat.shortLabel,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (c.stage == TutorialStage.windowCircuit)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${c.windowPositions[seat]}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TutorialColors.muted,
                      ),
                    ),
                  ),
                _windowButton(seat, -1),
                const SizedBox(width: 5),
                _windowButton(seat, 1),
              ],
            ),
          ),
        if (c.stage == TutorialStage.windowCircuit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: c.acceptsInput ? c.resetCircuit : null,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('처음 위치'),
            ),
          ),
      ],
    ),
    TutorialStage.wipers => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('wiper'),
        onPressed: c.acceptsInput
            ? () => _send(VehicleInputKind.wiper, 1)
            : null,
        icon: const Icon(Icons.water_drop_outlined),
        label: const Text('와이퍼 작동'),
      ),
    ),
    TutorialStage.departure => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final seat in CarSeat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              key: Key('belt-${seat.name}'),
              onPressed: c.acceptsInput
                  ? () => _send(
                      VehicleInputKind.seatbelt,
                      c.belts[seat]! ? 0 : 1,
                      seat: seat,
                    )
                  : null,
              icon: Icon(
                c.belts[seat]!
                    ? Icons.check_circle_outline
                    : Icons.person_outline,
                size: 19,
                color: c.belts[seat]! ? TutorialColors.success : null,
              ),
              label: Text('${seat.label} 벨트${c.belts[seat]! ? ' · 연결' : ''}'),
            ),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          key: const Key('accelerator'),
          onPressed: c.acceptsInput
              ? () {
                  _send(VehicleInputKind.accelerator, 0);
                  _send(VehicleInputKind.accelerator, 1);
                }
              : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('악셀 밟기 · 출발'),
        ),
      ],
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _windowButton(CarSeat seat, int direction) => SizedBox(
    width: 49,
    height: 48,
    child: OutlinedButton(
      key: Key('window-${seat.name}-${direction > 0 ? 'down' : 'up'}'),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              size: 20,
            ),
            Text(
              direction > 0 ? '내림' : '올림',
              style: const TextStyle(fontSize: 10, height: 1),
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
      OutlinedButton.icon(
        key: const Key('notes'),
        onPressed: c.visited.isEmpty ? null : _notes,
        icon: const Icon(Icons.menu_book_outlined, size: 19),
        label: const Text('나레이션 노트'),
      ),
      if (TutorialScript.hints.containsKey(c.stage))
        OutlinedButton.icon(
          key: const Key('hint'),
          onPressed: c.canHint && c.acceptsInput ? _hint : null,
          icon: const Icon(Icons.lightbulb_outline, size: 19),
          label: Text('힌트 ${c.hintLevel}/3'),
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
        onPressed: () => c.setManualPause(true),
        icon: const Icon(Icons.pause_rounded),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
      if (_voiceUnavailable)
        const Text(
          '한국어 음성 없음 · 자막으로 진행',
          style: TextStyle(fontSize: 11, color: TutorialColors.muted),
        ),
    ],
  );

  Widget _dialogueOverlay() => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: .72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
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
                        style: const TextStyle(color: TutorialColors.ice),
                      ),
                      const Spacer(),
                      Text(
                        '${c.dialogueIndex + 1} / ${c.dialogue.length}',
                        style: const TextStyle(color: TutorialColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    c.currentLine?.text ?? '',
                    style: const TextStyle(fontSize: 24, height: 1.7),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _dialogueNext(),
                      OutlinedButton.icon(
                        onPressed: _notes,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('노트에서 다시 듣기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '대사가 끝나면 자동으로 이어져요.',
                    style: TextStyle(color: TutorialColors.muted, fontSize: 12),
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
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                  size: 48,
                  color: TutorialColors.ice,
                ),
                const SizedBox(height: 20),
                Text(
                  !c.parked
                      ? 'P단에서 이야기를 이어가요'
                      : !c.connected
                      ? '차량 연결을 기다리고 있어요'
                      : '잠시 숨을 고르세요',
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  !c.parked
                      ? '정차 상태가 확인되면 다시 시작할 수 있어요.'
                      : !c.connected
                      ? '연결이 돌아오면 같은 퍼즐에서 계속해요.'
                      : '퍼즐 진행과 시간은 멈춰 있어요. 준비되면 돌아오세요.',
                  style: const TextStyle(
                    color: TutorialColors.muted,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 26),
                if (c.parked && c.connected)
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
      Positioned.fill(
        child: SnowBackdrop(time: _animation.value, shelter: true),
      ),
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
                    _eyebrow('TUTORIAL COMPLETE', color: TutorialColors.warm),
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
                        fontSize: 18,
                        color: Color(0xFFCCD8DE),
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
                          _stat('사용한 힌트', '${r.hintsUsed}회'),
                          _stat('최종 기록', formatTime(r.recordedTime)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '최종 기록 = 플레이 시간 + 힌트 1회당 1분 · 일시정지 시간 제외',
                      style: TextStyle(
                        fontSize: 12,
                        color: TutorialColors.muted,
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
                          onPressed: _demo && widget.controller == null
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
        style: const TextStyle(fontSize: 13, color: TutorialColors.muted),
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
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: color,
    ),
  );
  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: TutorialColors.panel.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TutorialColors.border),
    ),
    child: child,
  );
  Widget _tag(String text, {Color color = TutorialColors.ice}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color)),
  );

  String get _taskTitle => switch (c.stage) {
    TutorialStage.power => '배터리에서 나온 선을 따라\n실내등을 차례로 켜세요.',
    TutorialStage.glovebox => '얼어붙은 글로브박스에서\n수리도구를 꺼내세요.',
    TutorialStage.windowRequest => '창문을 조금 열어\n바깥 공기를 들여보세요.',
    TutorialStage.windowCircuit => '네 자리의 창문 버튼으로\n끊어진 회로를 이으세요.',
    TutorialStage.wipers => '앞유리 너머의\n대피소를 찾아보세요.',
    TutorialStage.departure => '안전벨트를 모두 연결하고\n대피소로 출발하세요.',
    _ => '',
  };
  String get _taskBody => switch (c.stage) {
    TutorialStage.power => '트렁크에서 시작하는 선이 단서예요.\n순서가 틀리면 처음부터 다시 연결해요.',
    TutorialStage.glovebox => '잠긴 걸까요, 얼어 있는 걸까요?\n따뜻한 바람이 도움이 될지도 몰라요.',
    TutorialStage.windowRequest => '어느 자리의 버튼이든 괜찮아요.\n올림이나 내림을 한 번 눌러보세요.',
    TutorialStage.windowCircuit =>
      '색마다 한 자리씩 맡아요. 올림·내림으로 선을 움직여 왼쪽 전원을 출구에 연결하세요.\n창문은 0~50%만 · 손 끼임에 주의하세요.',
    TutorialStage.wipers => '눈이 시야를 가리고 있어요.\n와이퍼가 움직일 공간을 확인해 주세요.',
    TutorialStage.departure =>
      _demo
          ? '네 자리 모두 확인하세요. 악셀은 화면 속 출발 연출이에요. 실제 차량은 움직이지 않아요.'
          : '전 좌석 안전벨트를 확인해 주세요. 실제 차량은 P단을 유지하세요.',
    _ => '',
  };

  String _stageTitle(TutorialStage stage) => switch (stage) {
    TutorialStage.intro || TutorialStage.blackout => '눈보라 속 정전',
    TutorialStage.power => '작은 불빛을 따라서',
    TutorialStage.glovebox => '얼어붙은 글로브박스',
    TutorialStage.windowRequest => '바깥 공기가 필요해',
    TutorialStage.windowCircuit => '엉켜 버린 창문 회로',
    TutorialStage.wipers => '눈 너머의 불빛',
    TutorialStage.departure => '모두 함께 출발',
    TutorialStage.arrival || TutorialStage.result => '대피소에 도착하다',
  };
}
