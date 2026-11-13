import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/game_session.dart';
import '../../vehicle/device_catalog.dart';
import '../../vehicle/vehicle_service.dart';
import 'lessons.dart';

/// Runs the tutorial questions against the car. Only reads the vehicle.
class LessonController extends ChangeNotifier {
  LessonController(
    this.vehicle,
    this.session, {
    this.lessons = tutorialLessons,
  }) {
    _gearSub = vehicle.watch(DeviceId.gear).listen((r) {
      parked = r.value == gearPark;
      notifyListeners();
    });
    _arm();
  }

  final VehicleService vehicle;
  final GameSession session;
  final List<Lesson> lessons;
  StreamSubscription<VehicleReading>? _gearSub;
  StreamSubscription<VehicleReading>? _deviceSub;

  int index = 0;
  bool solved = false;
  bool hintShown = false;

  /// The function was already on when the question started: turn it off
  /// and on again.
  bool alreadyOn = false;

  /// No gear reading yet counts as parked.
  bool parked = true;
  num? _baseline;

  Lesson get lesson => lessons[index];
  bool get isLast => index == lessons.length - 1;

  /// The check found this device missing or broken: solve it on screen.
  bool get byTouch => !session.canUse(lesson.device);

  void showHint() {
    hintShown = true;
    notifyListeners();
  }

  void solveByTouch() {
    if (byTouch && !solved) _solve();
  }

  /// Moves to the next question. False after the last one.
  bool next() {
    if (!solved || isLast) return false;
    index++;
    _arm();
    return true;
  }

  void _arm() {
    _deviceSub?.cancel();
    solved = false;
    hintShown = false;
    alreadyOn = false;
    _baseline = null;
    if (!byTouch) {
      _deviceSub = vehicle.watch(lesson.device).listen(_onReading);
    }
    notifyListeners();
  }

  // Solved when the function turns on after the question starts. A press
  // while not in P doesn't count.
  void _onReading(VehicleReading r) {
    if (_baseline == null) {
      _baseline = r.value;
      alreadyOn = r.value == 1;
      notifyListeners();
      return;
    }
    if (solved) return;
    if (parked && r.value == 1 && r.value != _baseline) return _solve();
    _baseline = r.value;
    alreadyOn = r.value == 1;
    notifyListeners();
  }

  void _solve() {
    solved = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _gearSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
