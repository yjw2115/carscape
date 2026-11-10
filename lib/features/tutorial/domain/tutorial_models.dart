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
  configuration,
  issue,
  cabinLight,
  passengerHeater,
  glovebox,
  window,
  wiper,
  seatbelt,
  parking,
  connection,
}

/// Logical tutorial inputs, independent of any shared vehicle SDK device IDs.
/// An external adapter must normalize window position to 0..100 percent open.
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

/// Seat inventory comes from the vehicle, separately from the four puzzle controls.
class VehicleSeat {
  const VehicleSeat(this.id, this.label, this.row, this.column);
  final String id;
  final String label;
  final int row;
  final int column;

  static VehicleSeat fromId(String id) {
    final match = RegExp(r'^ROW_([123])_(LEFT|CENTER|RIGHT)$').firstMatch(id);
    if (match == null) return VehicleSeat(id, id, 4, 1);
    final row = int.parse(match.group(1)!);
    final column = ['LEFT', 'CENTER', 'RIGHT'].indexOf(match.group(2)!);
    final label = row == 1 && column == 0
        ? '운전석'
        : row == 1 && column == 2
        ? '조수석'
        : '${row == 2 ? '뒷좌석' : '$row열'} ${['왼쪽', '가운데', '오른쪽'][column]}';
    return VehicleSeat(id, label, row, column);
  }

  static const demoIds = [
    'ROW_1_LEFT',
    'ROW_1_RIGHT',
    'ROW_2_LEFT',
    'ROW_2_CENTER',
    'ROW_2_RIGHT',
  ];
}

String areaForSeat(CarSeat seat) => switch (seat) {
  CarSeat.rearLeft => 'ROW_2_LEFT',
  CarSeat.rearRight => 'ROW_2_RIGHT',
  CarSeat.passenger => 'ROW_1_RIGHT',
  CarSeat.driver => 'ROW_1_LEFT',
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
