import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'tutorial_models.dart';
import 'tutorial_script.dart';

class TutorialController extends ChangeNotifier {
  TutorialController({this.options = const TutorialOptions()}) {
    if (options.enableClock) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    }
  }
  final TutorialOptions options;
  static const chapters = [
    TutorialStage.power,
    TutorialStage.glovebox,
    TutorialStage.ventilation,
    TutorialStage.escape,
  ];
  static const baseTemperature = 20.0;
  static const minimumTemperature = 16.0;

  /// Any rightward turn of at least this many degrees, measured from where
  /// the wheel was when the shelter came into view, finishes the escape.
  static const steeringTurn = 5.0;

  /// The front defroster only softens the snow; the wiper still clears it.
  static const maxMelt = .4;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  Duration _lastClock = Duration.zero;
  TutorialStage stage = TutorialStage.intro;
  TutorialStage? _pendingChapter;
  TutorialStage? get pendingChapter => _pendingChapter;
  int dialogueIndex = 0, dialogueRevision = 0;
  bool dialogueActive = false, manualPause = false, appInBackground = false;
  bool parked = true,
      connected = true,
      liveVehicleMode = false,
      vehicleConfigured = false;
  bool _gloveboxSensorAvailable = false;
  bool get gloveboxSensorAvailable => liveVehicleMode
      ? _gloveboxSensorAvailable
      : options.gloveboxSensorAvailable;
  Duration elapsed = Duration.zero, idleTime = Duration.zero;
  int hintsUsed = 0, windowMoves = 0, powerCount = 0;
  String feedback = '';
  bool gloveboxOpen = false;
  bool? _heaterState = false;
  bool? _wiperState = false;
  bool? _defrosterState = false;
  bool get heaterOn => _heaterState == true;
  bool get wiperOn => _wiperState == true;
  bool get defrosterOn => _defrosterState == true;
  bool _heaterActivated = false;
  bool _windowAdjusted = false;
  bool _wiperActivated = false;
  int lightResetRevision = 0;
  bool lightsResetting = false;
  final Map<CarSeat, bool> lights = {for (final s in CarSeat.values) s: false};
  final Map<CarSeat, bool?> _observedLights = {
    for (final s in CarSeat.values) s: false,
  };
  final Map<CarSeat, double?> windows = {for (final s in CarSeat.values) s: 0};
  final Map<String, bool?> doors = {
    for (final s in CarSeat.values) areaForSeat(s): false,
    'REAR': false,
  };
  final Map<String, String> vehicleIssues = {};
  final Map<String, Object?> vehicleCapabilities = {};
  final Map<TutorialStage, int> _hintLevels = {};
  final List<TutorialStage> visited = [];
  TutorialResult? result;
  bool usedTestNavigation = false;

  // Fictional game meters, never measurements of cabin gas or temperature.
  double gasLevel = 100, cabinTemperature = baseTemperature, frost = 0;
  double _ventilationStable = 0;
  bool coldCommentPlayed = false;
  int ambientRevision = 0;
  double? steeringAngle = 0;
  double visibility = 0;

  /// 0–[maxMelt]: how much of the windshield snow the defroster has softened.
  double melt = 0;
  double? _steeringBase;
  bool get shelterVisible => visibility >= .999;
  bool get inLightPuzzle =>
      stage == TutorialStage.blackout || stage == TutorialStage.power;
  int get step => switch (stage) {
    TutorialStage.intro || TutorialStage.blackout || TutorialStage.power => 1,
    TutorialStage.glovebox => 2,
    TutorialStage.ventilation => 3,
    _ => 4,
  };
  bool get hasSensorProblem =>
      liveVehicleMode &&
      vehicleIssues.keys.any(
        (key) => switch (stage) {
          TutorialStage.power =>
            key == 'lights' ||
                key == 'lightControl' ||
                key == 'lightReset' ||
                key.startsWith('light:'),
          TutorialStage.glovebox => key.startsWith('heater'),
          TutorialStage.ventilation =>
            key == 'windows' ||
                key.startsWith('window:') ||
                key == 'doors' ||
                key.startsWith('door:'),
          TutorialStage.escape => key == 'wiper' || key == 'steering',
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
  bool get _canAct =>
      playing &&
      !appInBackground &&
      parked &&
      connected &&
      !hasSensorProblem &&
      !dialogueActive &&
      pendingChapter == null;
  bool get acceptsInput => _canAct && !manualPause;
  bool get canOpenHint => _canAct && canHint;
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
  bool lightIsOn(CarSeat seat) => _observedLights[seat] == true;
  bool get ventilationKnown =>
      windows.values.every((v) => v != null) &&
      doors.isNotEmpty &&
      doors.values.every((v) => v != null);
  bool get _cabinOpen => doors.containsValue(true);
  bool _isCabinDoor(String area) => area == 'REAR' || area.startsWith('ROW_');
  double get ventilationUnits =>
      windows.values.fold(0.0, (sum, v) => sum + (v ?? 0) / 20);

  /// Piecewise linear: 20/40/60/80/100% costs 1/5/10/15/20 x.
  static double windowColdCost(double percent) {
    final p = percent.clamp(0.0, 100.0);
    if (p <= 20) return p / 20;
    if (p <= 40) return 1 + (p - 20) / 5;
    return 5 + (p - 40) / 4;
  }

  double get coldLoss =>
      windows.values.fold(0.0, (sum, v) => sum + windowColdCost(v ?? 0)) +
      doors.values.where((v) => v == true).length * 10;
  double get targetGas =>
      _cabinOpen ? 0 : (100 - ventilationUnits * 25).clamp(0.0, 100.0);
  double get targetTemperature => baseTemperature - coldLoss;
  bool get ventilationBalanced =>
      ventilationKnown &&
      windows.values.every((v) => v! >= 19.9) &&
      ventilationUnits >= 3.999 &&
      coldLoss <= 4.001 &&
      !_cabinOpen;

  void enableVehicleMode() {
    liveVehicleMode = true;
    connected = false;
    parked = false;
    _observedLights.updateAll((_, _) => null);
    _heaterState = null;
    _wiperState = null;
    _defrosterState = null;
    windows.updateAll((_, _) => null);
    doors.updateAll((_, _) => null);
    steeringAngle = null;
  }

  void start() {
    if (stage != TutorialStage.intro || !readyToStart) return;
    _clock.start();
    _lastClock = _clock.elapsed;
    _resetPower();
    _enter(TutorialStage.blackout);
  }

  void _enter(TutorialStage next) {
    final previous = stage;
    _pendingChapter = null;
    stage = next;
    if (!visited.contains(next)) visited.add(next);
    feedback = '';
    idleTime = Duration.zero;
    dialogueIndex = 0;
    dialogueActive = dialogue.isNotEmpty;
    dialogueRevision++;
    if (next == TutorialStage.power && previous != TutorialStage.blackout) {
      _resetPower();
      if (!liveVehicleMode) feedback = '';
    }
    if (next == TutorialStage.glovebox) _heaterActivated = false;
    if (next == TutorialStage.ventilation) {
      gasLevel = 100;
      cabinTemperature = baseTemperature;
      frost = 0;
      _ventilationStable = 0;
      _windowAdjusted = false;
    }
    if (next == TutorialStage.escape) {
      visibility = 0;
      melt = 0;
      _wiperActivated = false;
      _steeringBase = null;
    }
    if (next == TutorialStage.result) {
      _clock.stop();
      result = TutorialResult(
        playTime: elapsed,
        hintsUsed: hintsUsed,
        windowMoves: windowMoves,
        usedTestNavigation: usedTestNavigation,
      );
    }
    notifyListeners();
  }

  void _completeChapter(TutorialStage next) {
    if (!options.waitForChapterClear) {
      _enter(next);
      return;
    }
    _pendingChapter = next;
    notifyListeners();
  }

  void finishChapterClear(TutorialStage next) {
    if (paused || _pendingChapter != next) return;
    _lastClock = _clock.elapsed;
    _enter(next);
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
      _evaluate();
      notifyListeners();
    }
  }

  void tick([Duration? delta]) {
    final now = _clock.elapsed;
    final change = delta ?? now - _lastClock;
    _lastClock = now;
    if (!playing || paused || pendingChapter != null) return;
    elapsed += change;
    if (dialogueActive) {
      notifyListeners();
      return;
    }
    idleTime += change;
    final seconds = change.inMicroseconds / Duration.microsecondsPerSecond;
    if (stage == TutorialStage.ventilation && ventilationKnown) {
      gasLevel = _approach(gasLevel, targetGas, seconds * 25);
      cabinTemperature = _approach(
        cabinTemperature,
        targetTemperature,
        seconds * (targetTemperature < cabinTemperature ? 12 : 3),
      );
      frost = _approach(
        frost,
        ((minimumTemperature - cabinTemperature) / 10).clamp(0.0, 1.0),
        seconds * .4,
      );
      if (_windowAdjusted &&
          ventilationBalanced &&
          gasLevel <= .01 &&
          cabinTemperature >= minimumTemperature - .01) {
        _ventilationStable += seconds;
        if (_ventilationStable >= 1.5) _completeChapter(TutorialStage.escape);
      } else {
        _ventilationStable = 0;
      }
    } else if (stage == TutorialStage.escape) {
      if (defrosterOn && melt < maxMelt) {
        melt = math.min(maxMelt, melt + seconds * maxMelt / 6);
      }
      if (_wiperActivated && wiperOn && visibility < 1) {
        visibility = (visibility + seconds / 3).clamp(0.0, 1.0);
        // A wheel already turned before this moment does not count.
        if (shelterVisible) _steeringBase = steeringAngle;
      }
    }
    _evaluate();
    notifyListeners();
  }

  double _approach(double value, double target, double amount) => value < target
      ? math.min(value + amount, target)
      : math.max(value - amount, target);
  void setManualPause(bool value) {
    if (manualPause == value) return;
    manualPause = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    _evaluate();
    notifyListeners();
  }

  void setBackground(bool value) {
    if (appInBackground == value) return;
    appInBackground = value;
    _lastClock = _clock.elapsed;
    dialogueRevision++;
    _evaluate();
    notifyListeners();
  }

  void useHint({bool fromPausedMenu = false}) {
    if (!canOpenHint || (manualPause && !fromPausedMenu)) return;
    _hintLevels[stage] = hintLevel + 1;
    hintsUsed++;
    idleTime = Duration.zero;
    notifyListeners();
  }

  void _evaluate() {
    if (!acceptsInput) return;
    if (stage == TutorialStage.power &&
        !lightsResetting &&
        CarSeat.values.any((s) => lights[s] != (_observedLights[s] == true))) {
      _resetPower();
    }
    if (stage == TutorialStage.glovebox &&
        _heaterActivated &&
        heaterOn &&
        (!gloveboxSensorAvailable || gloveboxOpen)) {
      _completeChapter(TutorialStage.ventilation);
    }
    if (stage == TutorialStage.ventilation) {
      if (_cabinOpen) {
        _ventilationStable = 0;
      }
      if (coldLoss > 4.001 && !coldCommentPlayed) {
        coldCommentPlayed = true;
        ambientRevision++;
      }
    }
  }

  void confirmLightReset(int revision, {required bool success}) {
    if (!inLightPuzzle || revision != lightResetRevision) return;
    if (success) {
      // The native result is returned only after all four physical OFF readbacks.
      _observedLights.updateAll((_, _) => false);
      lightsResetting = false;
      vehicleIssues.remove('lightReset');
      feedback = '';
    } else {
      vehicleIssues['lightReset'] = '조명을 모두 끄지 못했어요. 연결을 확인해 주세요.';
    }
    notifyListeners();
  }

  void _resetPower() {
    powerCount = 0;
    lights.updateAll((_, _) => false);
    lightResetRevision++;
    lightsResetting = liveVehicleMode;
    feedback = liveVehicleMode ? '조명을 모두 끄고 있어요.' : '회로 연결이 끊어졌어요.';
    if (!liveVehicleMode) _observedLights.updateAll((_, _) => false);
  }

  void retryLightReset() {
    if (stage != TutorialStage.power) return;
    vehicleIssues.remove('lightReset');
    _resetPower();
    notifyListeners();
  }

  void receive(TutorialVehicleInput input) {
    if (input.kind == VehicleInputKind.configuration) {
      vehicleCapabilities.addAll(input.data ?? {});
      _gloveboxSensorAvailable = vehicleCapabilities['gloveboxOpen'] == true;
      final inventory = (vehicleCapabilities['doors'] as List?)?.cast<String>();
      if (inventory != null) {
        final previous = Map<String, bool?>.of(doors);
        doors.clear();
        for (final id in inventory.where(_isCabinDoor)) {
          doors[id] = previous[id];
        }
      }
      vehicleConfigured = true;
      notifyListeners();
      return;
    }
    if (input.kind == VehicleInputKind.issue) {
      final key = input.data?['feature'] as String? ?? 'vehicle';
      // The defroster is optional scenery; its absence never blocks play.
      if (key.startsWith('frontDefroster')) return;
      if (key.startsWith('door:') &&
          !_isCabinDoor(key.substring('door:'.length))) {
        return;
      }
      final before = paused;
      final message = input.data?['message'] as String? ?? '';
      if (message.isEmpty) {
        vehicleIssues.remove(key);
      } else {
        vehicleIssues[key] = message;
      }
      if (before != paused) dialogueRevision++;
      _evaluate();
      notifyListeners();
      return;
    }
    if (input.kind == VehicleInputKind.parking ||
        input.kind == VehicleInputKind.connection) {
      final value = input.known && input.value != 0;
      final before = paused;
      if (input.kind == VehicleInputKind.parking) {
        parked = value;
      } else {
        connected = value;
      }
      if (before != paused) {
        dialogueRevision++;
        _lastClock = _clock.elapsed;
      }
      _evaluate();
      notifyListeners();
      return;
    }
    final wasAccepting = acceptsInput;
    if (!liveVehicleMode && !wasAccepting) return;
    final on = input.known && input.value > 0;
    final freshAction =
        !input.initial && input.known && !paused && pendingChapter == null;
    final seat = input.seat;
    switch (input.kind) {
      case VehicleInputKind.passengerHeater:
        if (stage == TutorialStage.glovebox &&
            freshAction &&
            _heaterState == false &&
            on) {
          _heaterActivated = true;
        }
        _heaterState = input.known ? on : null;
      case VehicleInputKind.glovebox:
        gloveboxOpen = on && (heaterOn || liveVehicleMode);
      case VehicleInputKind.wiper:
        if (stage == TutorialStage.escape &&
            freshAction &&
            _wiperState == false &&
            on) {
          _wiperActivated = true;
        }
        _wiperState = input.known ? on : null;
      case VehicleInputKind.door:
        final area = input.areaId;
        if (area == null || !_isCabinDoor(area)) return;
        doors[area] = input.known ? on : null;
      case VehicleInputKind.steering:
        steeringAngle = input.known ? input.value.toDouble() : null;
        if (stage == TutorialStage.escape && shelterVisible && input.known) {
          final angle = input.value.toDouble();
          final base = _steeringBase;
          // The base follows the wheel leftward, so only a rightward change
          // from the wheel's position counts, wherever it started.
          if (base == null || angle < base) {
            _steeringBase = angle;
          } else if (wasAccepting &&
              !input.initial &&
              angle - base >= steeringTurn) {
            _enter(TutorialStage.arrival);
          }
        }
      case VehicleInputKind.frontDefroster:
        _defrosterState = input.known ? on : null;
      case VehicleInputKind.window:
        if (seat != null) {
          final previous = windows[seat];
          windows[seat] = input.known
              ? input.value.toDouble().clamp(0.0, 100.0)
              : null;
          if (stage == TutorialStage.ventilation &&
              freshAction &&
              previous != null &&
              previous != windows[seat]) {
            _windowAdjusted = true;
          }
          if (wasAccepting &&
              !input.initial &&
              stage == TutorialStage.ventilation &&
              previous != windows[seat]) {
            windowMoves++;
          }
        }
      case VehicleInputKind.cabinLight:
        if (seat == null) break;
        final previous = _observedLights[seat];
        _observedLights[seat] = input.known ? on : null;
        if (stage == TutorialStage.power &&
            !lightsResetting &&
            wasAccepting &&
            !input.initial &&
            input.known) {
          if (!on && lights[seat] == true) {
            _resetPower();
          } else if (on && previous == false) {
            if (seat != CarSeat.values[powerCount]) {
              _resetPower();
            } else {
              lights[seat] = true;
              powerCount++;
              feedback = '';
              if (powerCount == 4) _completeChapter(TutorialStage.glovebox);
            }
          }
        }
      default:
        break;
    }
    if (wasAccepting && !input.initial) idleTime = Duration.zero;
    _evaluate();
    notifyListeners();
  }

  void moveWindow(CarSeat seat, int direction) => receive(
    TutorialVehicleInput(
      VehicleInputKind.window,
      ((windows[seat] ?? 0) + direction * 20).clamp(0, 100),
      seat: seat,
    ),
  );

  /// Temporary navigation does not change windows, doors, HVAC, or steering.
  void testNavigate(int direction) {
    usedTestNavigation = true;
    final current = chapters.indexOf(stage);
    final index = current < 0
        ? (stage == TutorialStage.intro || stage == TutorialStage.blackout
              ? 0
              : (direction < 0 ? 3 : 4))
        : current + direction;
    manualPause = false;
    if (!_clock.isRunning) {
      _clock.start();
      _lastClock = _clock.elapsed;
    }
    if (index < 0) {
      _enter(TutorialStage.intro);
    } else if (index >= chapters.length && stage == TutorialStage.arrival) {
      _enter(TutorialStage.result);
    } else if (index >= chapters.length) {
      _enter(TutorialStage.arrival);
    } else {
      _enter(chapters[index]);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }
}
