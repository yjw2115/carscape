import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tutorial_models.dart';
import 'tutorial_script.dart';

/// Tutorial rules consume observations, never vehicle control commands.
class TutorialController extends ChangeNotifier {
  TutorialController({this.options = const TutorialOptions()}) {
    _setBeltInventory(VehicleSeat.demoIds);
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
  bool liveVehicleMode = false;
  bool vehicleConfigured = false;
  bool _gloveboxSensorAvailable = false;
  bool get gloveboxSensorAvailable => liveVehicleMode
      ? _gloveboxSensorAvailable
      : options.gloveboxSensorAvailable;
  Duration elapsed = Duration.zero;
  Duration idleTime = Duration.zero;
  int hintsUsed = 0;
  int windowMoves = 0;
  String feedback = '';
  int powerCount = 0;
  bool heaterOn = false;
  bool gloveboxOpen = false;
  bool wiperOn = false;
  bool _waitingForLightsOff = false;
  final Map<CarSeat, bool> lights = {for (final s in CarSeat.values) s: false};
  final Map<CarSeat, bool?> _observedLights = {
    for (final s in CarSeat.values) s: false,
  };
  final Map<CarSeat, double> _observedWindows = {
    for (final s in CarSeat.values) s: 0,
  };
  final Map<CarSeat, int> windowPositions = {
    for (final s in CarSeat.values) s: 0,
  };
  List<VehicleSeat> beltSeats = [];
  final Map<String, bool?> belts = {};
  final Map<String, bool?> _observedBelts = {};
  final Map<String, String> vehicleIssues = {};
  final Map<String, Object?> vehicleCapabilities = {};
  final Map<TutorialStage, int> _hintLevels = {};
  final List<TutorialStage> visited = [];
  TutorialResult? result;

  static const circuitBaseIn = [0, 1, 0, -1];
  static const circuitDelta = [1, -1, -1, 1];
  static const initialOffsets = [0, -1, 1, 0];
  final List<int> circuitOffsets = [...initialOffsets];
  final Set<CarSeat> circuitTouched = {};

  bool get hasSensorProblem =>
      liveVehicleMode &&
      vehicleIssues.keys.any(
        (key) => switch (stage) {
          TutorialStage.power => key == 'lights' || key.startsWith('light:'),
          TutorialStage.glovebox => key.startsWith('heater'),
          TutorialStage.windowRequest || TutorialStage.windowCircuit =>
            key == 'windows' || key.startsWith('window:'),
          TutorialStage.wipers => key == 'wiper',
          TutorialStage.departure =>
            key == 'belts' || key == 'seatInventory' || key.startsWith('belt:'),
          _ => false,
        },
      );
  bool get paused =>
      manualPause ||
      appInBackground ||
      !parked ||
      !connected ||
      hasSensorProblem;
  bool get playing =>
      stage != TutorialStage.intro && stage != TutorialStage.result;
  bool get acceptsInput => playing && !paused && !dialogueActive;
  bool get allBelts =>
      belts.isNotEmpty && belts.values.every((value) => value == true);
  int get buckledCount => belts.values.where((value) => value == true).length;
  bool lightIsOn(CarSeat seat) => _observedLights[seat] == true;
  bool get readyToStart =>
      !liveVehicleMode || (connected && parked && vehicleConfigured);
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

  void enableVehicleMode() {
    liveVehicleMode = true;
    connected = false;
    parked = false;
    _observedBelts.clear();
    _observedLights.updateAll((_, _) => null);
    _setBeltInventory(const []);
  }

  void _setBeltInventory(Iterable<String> ids) {
    final unique = ids.toSet().toList()..sort();
    final previous = Map<String, bool?>.of(belts);
    belts.clear();
    beltSeats = unique.map(VehicleSeat.fromId).toList();
    for (final id in unique) {
      belts[id] = _observedBelts.containsKey(id)
          ? _observedBelts[id]
          : previous[id];
    }
  }

  void start() {
    if (stage != TutorialStage.intro || !readyToStart) return;
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
    if (next == TutorialStage.power && liveVehicleMode) {
      _waitingForLightsOff = !_observedLights.values.every(
        (value) => value == false,
      );
    }
    if (next == TutorialStage.windowCircuit) {
      for (final seat in CarSeat.values) {
        if (!liveVehicleMode) _observedWindows[seat] = 0;
        windowPositions[seat] = liveVehicleMode
            ? (_observedWindows[seat]! / 10).floor() * 10
            : 0;
        circuitOffsets[seat.index] =
            initialOffsets[seat.index] + windowPositions[seat]! ~/ 10;
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
      _evaluateContinuousState();
      notifyListeners();
    }
  }

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
    if (manualPause == value) return;
    manualPause = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    _evaluateContinuousState();
    notifyListeners();
  }

  void setBackground(bool value) {
    if (appInBackground == value) return;
    appInBackground = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    _evaluateContinuousState();
    notifyListeners();
  }

  void useHint() {
    if (!acceptsInput || !canHint) return;
    _hintLevels[stage] = hintLevel + 1;
    hintsUsed++;
    idleTime = Duration.zero;
    notifyListeners();
  }

  void _evaluateContinuousState() {
    if (!acceptsInput) return;
    if (liveVehicleMode &&
        stage == TutorialStage.power &&
        CarSeat.values.any(
          (seat) => lights[seat] == true && _observedLights[seat] != true,
        )) {
      _resetPower();
    }
    if (liveVehicleMode && stage == TutorialStage.windowCircuit) {
      for (final seat in CarSeat.values) {
        if (stage != TutorialStage.windowCircuit) break;
        _moveCircuit(seat, _observedWindows[seat]!.round());
      }
      if (stage == TutorialStage.windowCircuit && _circuitComplete) {
        _enter(TutorialStage.wipers);
      }
    }
    if (stage == TutorialStage.glovebox &&
        heaterOn &&
        (!gloveboxSensorAvailable || gloveboxOpen)) {
      _enter(TutorialStage.windowRequest);
    } else if (stage == TutorialStage.wipers && wiperOn) {
      _enter(TutorialStage.departure);
    } else if (stage == TutorialStage.departure && allBelts) {
      _enter(TutorialStage.arrival);
    }
  }

  void receive(TutorialVehicleInput input) {
    if (input.kind == VehicleInputKind.configuration) {
      vehicleCapabilities.addAll(input.data ?? {});
      _gloveboxSensorAvailable = vehicleCapabilities['gloveboxOpen'] == true;
      final inventory = <String>{
        ...((vehicleCapabilities['beltSeats'] as List?) ?? []).cast<String>(),
        ...((vehicleCapabilities['seatInventory'] as List?) ?? [])
            .cast<String>(),
      };
      _setBeltInventory(inventory);
      vehicleConfigured = true;
      notifyListeners();
      return;
    }
    if (input.kind == VehicleInputKind.issue) {
      final wasPaused = paused;
      final key = input.data?['feature'] as String? ?? 'vehicle';
      final message = input.data?['message'] as String? ?? '';
      if (message.isEmpty) {
        vehicleIssues.remove(key);
      } else {
        vehicleIssues[key] = message;
      }
      if (key.startsWith('belt:') && message.isNotEmpty) {
        belts[key.substring(5)] = null;
      }
      if (wasPaused != paused) dialogueRevision++;
      _evaluateContinuousState();
      notifyListeners();
      return;
    }
    if (input.kind == VehicleInputKind.parking ||
        input.kind == VehicleInputKind.connection) {
      final value = input.known && input.value != 0;
      final previous = input.kind == VehicleInputKind.parking
          ? parked
          : connected;
      if (input.kind == VehicleInputKind.parking) {
        parked = value;
      } else {
        connected = value;
      }
      if (value != previous) {
        _lastClock = _clock.elapsed;
        dialogueRevision++;
        _evaluateContinuousState();
        notifyListeners();
      }
      return;
    }

    final on = input.known && input.value > 0;
    final seat = input.seat;
    final wasAccepting = acceptsInput;
    if (!liveVehicleMode && !wasAccepting) return;
    // Cache physical states even under narration, notes, P pause, or background.
    // Returning to the story evaluates current conditions, never a stale belt.
    switch (input.kind) {
      case VehicleInputKind.passengerHeater:
        heaterOn = on;
      case VehicleInputKind.glovebox:
        gloveboxOpen = on && (heaterOn || liveVehicleMode);
      case VehicleInputKind.wiper:
        wiperOn = on;
      case VehicleInputKind.seatbelt:
        final id = input.areaId ?? (seat == null ? null : areaForSeat(seat));
        if (id != null) {
          _observedBelts[id] = input.known ? on : null;
          if (belts.containsKey(id)) belts[id] = input.known ? on : null;
        }
      default:
        break;
    }

    if (input.kind == VehicleInputKind.cabinLight && seat != null) {
      final previous = _observedLights[seat];
      _observedLights[seat] = input.known ? on : null;
      if (stage == TutorialStage.power &&
          _waitingForLightsOff &&
          _observedLights.values.every((value) => value == false)) {
        _waitingForLightsOff = false;
      }
      if (wasAccepting &&
          !input.initial &&
          input.known &&
          stage == TutorialStage.power) {
        if (!on && lights[seat] == true) {
          _resetPower();
        } else if (on && previous == false && !_waitingForLightsOff) {
          if (seat != CarSeat.values[powerCount]) {
            _resetPower();
          } else {
            lights[seat] = true;
            powerCount++;
            feedback = '${seat.label} 연결!';
            if (powerCount == 4) _enter(TutorialStage.glovebox);
          }
        }
      }
    } else if (input.kind == VehicleInputKind.window &&
        seat != null &&
        input.known) {
      final previousPhysical = _observedWindows[seat]!;
      _observedWindows[seat] = input.value.toDouble();
      if (wasAccepting && !input.initial && input.value != previousPhysical) {
        if (stage == TutorialStage.windowRequest) {
          _enter(TutorialStage.windowCircuit);
        } else if (stage == TutorialStage.windowCircuit) {
          _moveCircuit(seat, input.value.round());
        }
      } else if (!liveVehicleMode &&
          wasAccepting &&
          stage == TutorialStage.windowRequest) {
        // A preview button can be clicked at its end stop; real SDK positions cannot.
        _enter(TutorialStage.windowCircuit);
      }
    } else if (wasAccepting &&
        stage == TutorialStage.glovebox &&
        input.kind == VehicleInputKind.glovebox &&
        on &&
        !heaterOn) {
      feedback = '꽁꽁 얼어 열리지 않아요.';
    }
    if (wasAccepting && !input.initial) idleTime = Duration.zero;
    _evaluateContinuousState();
    notifyListeners();
  }

  void _resetPower() {
    powerCount = 0;
    lights.updateAll((_, _) => false);
    feedback = '회로 연결이 끊어졌어요.';
    if (liveVehicleMode) {
      _waitingForLightsOff = !_observedLights.values.every(
        (value) => value == false,
      );
    } else {
      _observedLights.updateAll((_, _) => false);
    }
  }

  void _moveCircuit(CarSeat seat, int next) {
    if (next < 0 || next > 50) {
      feedback = '창문은 0~50% 안에서 움직여 주세요.';
      return;
    }
    final previous = windowPositions[seat]!;
    final target = (next / 10).floor() * 10;
    if (target == previous) return;
    windowPositions[seat] = target;
    circuitOffsets[seat.index] = initialOffsets[seat.index] + target ~/ 10;
    circuitTouched.add(seat);
    windowMoves += ((target - previous) ~/ 10).abs();
    feedback = '전류가 $connectedGates/4 구간까지 흐르고 있어요.';
    if (_circuitComplete) {
      _enter(TutorialStage.wipers);
    }
  }

  bool get _circuitComplete =>
      connectedGates == 4 &&
      (liveVehicleMode || circuitTouched.length == 4) &&
      (!liveVehicleMode ||
          _observedWindows.values.every((value) => value >= 0 && value <= 50));

  void moveWindow(CarSeat seat, int direction) {
    final next = (windowPositions[seat]! + direction * 10).clamp(0, 50);
    receive(TutorialVehicleInput(VehicleInputKind.window, next, seat: seat));
  }

  void resetCircuit() {
    if (liveVehicleMode ||
        !acceptsInput ||
        stage != TutorialStage.windowCircuit) {
      return;
    }
    for (final seat in CarSeat.values) {
      windowPositions[seat] = 0;
      _observedWindows[seat] = 0;
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
