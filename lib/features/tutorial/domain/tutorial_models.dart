enum TutorialStage {
  intro,
  blackout,
  power,
  glovebox,
  windowRequest,
  windowCircuit,
  wipers,
  departure,
  arrival,
  result,
}

enum CarSeat {
  rearLeft('뒷좌석 왼쪽', '뒤 왼쪽'),
  rearRight('뒷좌석 오른쪽', '뒤 오른쪽'),
  passenger('조수석', '조수석'),
  driver('운전석', '운전석');

  const CarSeat(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

enum VehicleInputKind {
  cabinLight,
  passengerHeater,
  glovebox,
  window,
  wiper,
  seatbelt,
  accelerator,
  parking,
  connection,
}

/// Logical tutorial inputs, independent of any shared vehicle SDK device IDs.
/// An external adapter must normalize window position to 0..100 percent open.
class TutorialVehicleInput {
  const TutorialVehicleInput(this.kind, this.value, {this.seat});
  final VehicleInputKind kind;
  final num value;
  final CarSeat? seat;
}

class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker;
  final String text;
}

class TutorialOptions {
  const TutorialOptions({
    this.gloveboxSensorAvailable = true,
    this.enableClock = true,
  });

  /// False: passenger heater alone completes the glovebox chapter.
  final bool gloveboxSensorAvailable;
  final bool enableClock;
}

class TutorialResult {
  const TutorialResult({
    required this.playTime,
    required this.hintsUsed,
    required this.windowMoves,
  });
  final Duration playTime;
  final int hintsUsed;
  final int windowMoves;
  Duration get recordedTime => playTime + Duration(minutes: hintsUsed);
}
