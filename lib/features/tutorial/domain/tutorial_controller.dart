import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tutorial_models.dart';
import 'tutorial_script.dart';

/// Owns only 문성훈's tutorial flow. Vehicle events and UI simulation use the
/// same reducer; no vehicle control/write method is exposed here.
class TutorialController extends ChangeNotifier {
  TutorialController({this.options = const TutorialOptions()}) {
    if (options.enableClock) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    }
  }

  final TutorialOptions options;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  Duration _lastClock = Duration.zero;
  TutorialStage stage = TutorialStage.intro;
  int dialogueIndex = 0;
  bool dialogueActive = false;
  int dialogueRevision = 0;
  bool manualPause = false;
  bool appInBackground = false;
  bool parked = true;
  bool connected = true;
  Duration elapsed = Duration.zero;
  Duration idleTime = Duration.zero;
  int hintsUsed = 0;
  int windowMoves = 0;
  String feedback = '';
  int powerCount = 0;
  bool heaterOn = false;
  bool gloveboxOpen = false;
  bool wiperOn = false;
  bool _pedalPressed = false;
  final Map<CarSeat, bool> lights = {for (final s in CarSeat.values) s: false};
  final Map<CarSeat, bool> belts = {for (final s in CarSeat.values) s: false};
  final Map<CarSeat, int> windowPositions = {
    for (final s in CarSeat.values) s: 0,
  };
  final Map<TutorialStage, int> _hintLevels = {};
  final List<TutorialStage> visited = [];
  TutorialResult? result;

  // Each gate is a vertical wire with a different inlet/outlet offset. Matching
  // only the first gate isn't enough: the current must cross all four gates.
  static const circuitBaseIn = [0, 1, 0, -1];
  static const circuitDelta = [1, -1, -1, 1];
  static const initialOffsets = [0, -1, 1, 0];
  final List<int> circuitOffsets = [...initialOffsets];
  final Set<CarSeat> circuitTouched = {};

  bool get paused => manualPause || appInBackground || !parked || !connected;
  bool get playing =>
      stage != TutorialStage.intro && stage != TutorialStage.result;
  bool get acceptsInput => playing && !paused && !dialogueActive;
  bool get allBelts => belts.values.every((value) => value);
  List<DialogueLine> get dialogue => TutorialScript.dialogue[stage] ?? const [];
  DialogueLine? get currentLine =>
      dialogue.isEmpty ? null : dialogue[dialogueIndex];
  int get hintLevel => _hintLevels[stage] ?? 0;
  bool get canHint => TutorialScript.hints.containsKey(stage) && hintLevel < 3;
  bool get showIdleHelp => idleTime >= const Duration(seconds: 45) && canHint;
  String get hintText =>
      hintLevel == 0 ? '' : TutorialScript.hints[stage]![hintLevel - 1];
  int get step => switch (stage) {
    TutorialStage.intro || TutorialStage.blackout || TutorialStage.power => 1,
    TutorialStage.glovebox => 2,
    TutorialStage.windowRequest || TutorialStage.windowCircuit => 3,
    TutorialStage.wipers => 4,
    _ => 5,
  };

  int get connectedGates {
    int row = 2;
    int count = 0;
    for (int i = 0; i < 4; i++) {
      final inlet = circuitBaseIn[i] + circuitOffsets[i];
      if (inlet != row) break;
      row = inlet + circuitDelta[i];
      count++;
    }
    return count == 4 && row != 2 ? 3 : count;
  }

  void start() {
    if (stage != TutorialStage.intro) return;
    _clock.start();
    _enter(TutorialStage.blackout);
  }

  void _enter(TutorialStage next) {
    stage = next;
    visited.add(next);
    feedback = '';
    idleTime = Duration.zero;
    dialogueIndex = 0;
    dialogueActive = dialogue.isNotEmpty;
    dialogueRevision++;
    if (next == TutorialStage.windowCircuit) {
      for (final seat in CarSeat.values) {
        windowPositions[seat] = 0;
      }
    }
    if (next == TutorialStage.result) {
      _clock.stop();
      result = TutorialResult(
        playTime: elapsed,
        hintsUsed: hintsUsed,
        windowMoves: windowMoves,
      );
    }
    notifyListeners();
  }

  void advanceDialogue() {
    if (paused || !dialogueActive) return;
    if (dialogueIndex < dialogue.length - 1) {
      dialogueIndex++;
      dialogueRevision++;
      notifyListeners();
      return;
    }
    dialogueActive = false;
    dialogueRevision++;
    if (stage == TutorialStage.blackout) {
      _enter(TutorialStage.power);
    } else if (stage == TutorialStage.arrival) {
      _enter(TutorialStage.result);
    } else {
      notifyListeners();
    }
  }

  /// Call with a fixed delta in tests; production uses a monotonic clock so
  /// delayed callbacks and system clock adjustments cannot corrupt the score.
  void tick([Duration? delta]) {
    final now = _clock.elapsed;
    final change = delta ?? now - _lastClock;
    _lastClock = now;
    if (!playing || paused) return;
    elapsed += change;
    if (!dialogueActive) idleTime += change;
    notifyListeners();
  }

  void setManualPause(bool value) {
    manualPause = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    notifyListeners();
  }

  void setBackground(bool value) {
    appInBackground = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    notifyListeners();
  }

  void useHint() {
    if (!acceptsInput || !canHint) return;
    _hintLevels[stage] = hintLevel + 1;
    hintsUsed++;
    idleTime = Duration.zero;
    notifyListeners();
  }

  void receive(TutorialVehicleInput input) {
    // Safety and connection signals always take priority, including dialogue.
    if (input.kind == VehicleInputKind.parking ||
        input.kind == VehicleInputKind.connection) {
      if (input.kind == VehicleInputKind.parking) {
        parked = input.value != 0;
      } else {
        connected = input.value != 0;
      }
      _pedalPressed = false;
      _lastClock = _clock.elapsed;
      dialogueRevision++;
      notifyListeners();
      return;
    }
    if (!acceptsInput) return;
    idleTime = Duration.zero;
    final on = input.value > 0;
    final seat = input.seat;
    switch (input.kind) {
      case VehicleInputKind.cabinLight:
        if (stage != TutorialStage.power || seat == null) break;
        if (!on || lights[seat] == true) break;
        if (seat != CarSeat.values[powerCount]) {
          powerCount = 0;
          lights.updateAll((_, _) => false);
          feedback = '선이 끊어졌어요. 트렁크 배터리에서 다시 따라가 볼까요?';
        } else {
          lights[seat] = true;
          powerCount++;
          feedback = '${seat.label} 연결!';
          if (powerCount == 4) _enter(TutorialStage.glovebox);
        }
      case VehicleInputKind.passengerHeater:
        if (stage != TutorialStage.glovebox) break;
        heaterOn = on;
        feedback = on
            ? '따뜻한 바람에 얼음이 녹았어요. 글로브박스를 열어보세요.'
            : '조수석이 다시 차가워지고 있어요.';
        if (on && !options.gloveboxSensorAvailable) {
          _enter(TutorialStage.windowRequest);
        }
      case VehicleInputKind.glovebox:
        if (stage != TutorialStage.glovebox || !on) break;
        if (!heaterOn) {
          feedback = '꽁꽁 얼어 열리지 않아요. 먼저 따뜻하게 만들어야 해요.';
        } else {
          gloveboxOpen = true;
          _enter(TutorialStage.windowRequest);
        }
      case VehicleInputKind.window:
        if (seat == null) break;
        if (stage == TutorialStage.windowRequest) {
          _enter(TutorialStage.windowCircuit);
          break;
        }
        if (stage != TutorialStage.windowCircuit) break;
        final newPosition = input.value.round();
        if (newPosition < 0 || newPosition > 50) {
          feedback = '창문은 0~50% 안에서 움직여 주세요.';
          break;
        }
        final previous = windowPositions[seat]!;
        // One circuit step for each 10% position change, ignoring sensor jitter.
        final movement = ((newPosition - previous) / 10).truncate();
        if (movement == 0) break;
        windowPositions[seat] = previous + movement * 10;
        final i = seat.index;
        circuitOffsets[i] = initialOffsets[i] + windowPositions[seat]! ~/ 10;
        circuitTouched.add(seat);
        windowMoves += movement.abs();
        feedback = connectedGates == 4
            ? '모든 회로가 이어졌어요!'
            : '전류가 $connectedGates/4 구간까지 흐르고 있어요.';
        if (connectedGates == 4 && circuitTouched.length == 4) {
          _enter(TutorialStage.wipers);
        }
      case VehicleInputKind.wiper:
        if (stage != TutorialStage.wipers) break;
        wiperOn = on;
        if (on) _enter(TutorialStage.departure);
      case VehicleInputKind.seatbelt:
        if (stage != TutorialStage.departure || seat == null) break;
        belts[seat] = on;
        feedback = allBelts
            ? '모두 준비됐어요. 이제 대피소로 출발해요!'
            : '${belts.values.where((b) => b).length}/4명 안전벨트 연결';
      case VehicleInputKind.accelerator:
        if (stage != TutorialStage.departure) break;
        final rising = on && !_pedalPressed;
        _pedalPressed = on;
        if (rising && allBelts) {
          _enter(TutorialStage.arrival);
        } else if (rising) {
          feedback = '아직 벨트를 매지 않은 친구가 있어요. 네 자리 모두 확인해 주세요.';
        }
      case VehicleInputKind.parking || VehicleInputKind.connection:
        break;
    }
    notifyListeners();
  }

  void moveWindow(CarSeat seat, int direction) {
    final next = (windowPositions[seat]! + direction * 10).clamp(0, 50);
    receive(TutorialVehicleInput(VehicleInputKind.window, next, seat: seat));
  }

  void resetCircuit() {
    if (!acceptsInput || stage != TutorialStage.windowCircuit) return;
    for (final seat in CarSeat.values) {
      windowPositions[seat] = 0;
    }
    circuitOffsets.setAll(0, initialOffsets);
    circuitTouched.clear();
    feedback = '회로를 처음 위치로 돌렸어요.';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }
}
