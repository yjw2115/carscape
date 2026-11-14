enum TutorialStage {
  intro,
  blackout,
  power,
  glovebox,
  ventilation,
  escape,
  arrival,
  result,
}

enum CarSeat {
  rearLeft('뒷좌석 왼쪽', '뒤 왼쪽'),
  rearRight('뒷좌석 오른쪽', '뒤 오른쪽'),
  driver('운전석', '운전석'),
  passenger('조수석', '조수석');

  const CarSeat(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

enum VehicleInputKind {
  configuration,
  issue,
  cabinLight,
  passengerHeater,
  glovebox,
  window,
  door,
  wiper,
  frontDefroster,
  steering,
  parking,
  connection,
}

/// Window values are percent open; steering is degrees (right positive).
class TutorialVehicleInput {
  const TutorialVehicleInput(
    this.kind,
    this.value, {
    this.seat,
    this.areaId,
    this.initial = false,
    this.known = true,
    this.data,
  });
  final VehicleInputKind kind;
  final num value;
  final CarSeat? seat;
  final String? areaId;
  final bool initial;
  final bool known;
  final Map<String, Object?>? data;
}

String areaForSeat(CarSeat seat) => switch (seat) {
  CarSeat.rearLeft => 'ROW_2_LEFT',
  CarSeat.rearRight => 'ROW_2_RIGHT',
  CarSeat.driver => 'ROW_1_LEFT',
  CarSeat.passenger => 'ROW_1_RIGHT',
};
CarSeat? seatForArea(String? id) {
  for (final seat in CarSeat.values) {
    if (areaForSeat(seat) == id) return seat;
  }
  return null;
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
    this.waitForChapterClear = false,
  });
  final bool gloveboxSensorAvailable;
  final bool enableClock;
  final bool waitForChapterClear;
}

class TutorialResult {
  const TutorialResult({
    required this.playTime,
    required this.hintsUsed,
    required this.windowMoves,
    this.usedTestNavigation = false,
  });
  final Duration playTime;
  final int hintsUsed;
  final int windowMoves;
  final bool usedTestNavigation;
  Duration get recordedTime => playTime + Duration(minutes: hintsUsed);
}
