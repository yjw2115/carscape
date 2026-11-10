import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/integration/pleos_tutorial_input_source.dart';

void finishDialogue(TutorialController c) {
  while (c.dialogueActive) {
    c.advanceDialogue();
  }
}

void initialize(
  TutorialController c, {
  List<String> seats = VehicleSeat.demoIds,
}) {
  c.enableVehicleMode();
  c.receive(
    TutorialVehicleInput(
      VehicleInputKind.configuration,
      0,
      data: {'beltSeats': seats, 'seatInventory': seats, 'gloveboxOpen': false},
    ),
  );
  for (final seat in CarSeat.values) {
    c.receive(
      TutorialVehicleInput(
        VehicleInputKind.cabinLight,
        0,
        seat: seat,
        initial: true,
      ),
    );
    c.receive(
      TutorialVehicleInput(
        VehicleInputKind.window,
        0,
        seat: seat,
        initial: true,
      ),
    );
  }
  c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 1));
  c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 1));
}

void reachDeparture(TutorialController c) {
  c.start();
  finishDialogue(c);
  for (final seat in CarSeat.values) {
    c.receive(TutorialVehicleInput(VehicleInputKind.cabinLight, 1, seat: seat));
  }
  finishDialogue(c);
  c.receive(const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1));
  finishDialogue(c);
  c.receive(
    const TutorialVehicleInput(
      VehicleInputKind.window,
      10,
      seat: CarSeat.driver,
    ),
  );
  finishDialogue(c);
  const targets = [20, 30, 10, 20];
  for (final seat in CarSeat.values) {
    c.receive(
      TutorialVehicleInput(
        VehicleInputKind.window,
        targets[seat.index],
        seat: seat,
      ),
    );
  }
  finishDialogue(c);
  c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
  finishDialogue(c);
}

void main() {
  late TutorialController c;
  setUp(() {
    c = TutorialController(options: const TutorialOptions(enableClock: false));
  });
  tearDown(() {
    c.dispose();
  });

  test(
    'real observations complete the story; center belt is required, no accelerator',
    () {
      initialize(c);
      reachDeparture(c);
      expect(c.stage, TutorialStage.departure);
      for (final seat in c.beltSeats.where(
        (seat) => seat.id != 'ROW_2_CENTER',
      )) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.seatbelt, 1, areaId: seat.id),
        );
      }
      expect(c.buckledCount, 4);
      expect(c.stage, TutorialStage.departure);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.seatbelt,
          1,
          areaId: 'ROW_2_CENTER',
        ),
      );
      expect(c.stage, TutorialStage.arrival);
      finishDialogue(c);
      expect(c.stage, TutorialStage.result);
    },
  );

  test(
    'initial ON values cannot solve light sequence; wrong order requires actual OFF first',
    () {
      initialize(c);
      c.start();
      finishDialogue(c);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.driver,
        ),
      );
      for (final seat in CarSeat.values) {
        c.receive(
          TutorialVehicleInput(
            VehicleInputKind.cabinLight,
            1,
            seat: seat,
            initial: true,
          ),
        );
      }
      expect(c.powerCount, 0);
      for (final seat in CarSeat.values) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.cabinLight, 0, seat: seat),
        );
      }
      for (final seat in CarSeat.values) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.cabinLight, 1, seat: seat),
        );
      }
      expect(c.stage, TutorialStage.glovebox);
    },
  );

  test(
    'belt inventory includes third-row and center seats without assuming four or five',
    () {
      final ids = [
        for (int row = 1; row <= 3; row++)
          for (final side in ['LEFT', 'CENTER', 'RIGHT']) 'ROW_${row}_$side',
      ];
      initialize(c, seats: ids);
      reachDeparture(c);
      for (final id in ids.take(8)) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.seatbelt, 1, areaId: id),
        );
      }
      expect(c.stage, TutorialStage.departure);
      expect(c.beltSeats.length, 9);
      c.receive(
        TutorialVehicleInput(VehicleInputKind.seatbelt, 1, areaId: ids.last),
      );
      expect(c.stage, TutorialStage.arrival);
    },
  );

  test(
    'cached belt updates before capability report are preserved; unreadable seats block',
    () {
      c.enableVehicleMode();
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.seatbelt,
          1,
          areaId: 'ROW_2_CENTER',
          initial: true,
        ),
      );
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.configuration,
          0,
          data: {
            'beltSeats': ['ROW_1_LEFT'],
            'seatInventory': ['ROW_1_LEFT', 'ROW_2_CENTER'],
          },
        ),
      );
      expect(c.belts['ROW_2_CENTER'], isTrue);
      expect(c.allBelts, isFalse);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.issue,
          0,
          data: {
            'feature': 'belt:ROW_2_CENTER',
            'message': 'sensor unavailable',
          },
        ),
      );
      expect(c.belts['ROW_2_CENTER'], isNull);
    },
  );

  test(
    'unbuckling while paused updates current state and prevents stale auto-clear',
    () {
      initialize(c);
      reachDeparture(c);
      c.setManualPause(true);
      for (final seat in c.beltSeats) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.seatbelt, 1, areaId: seat.id),
        );
      }
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.seatbelt,
          0,
          areaId: 'ROW_2_CENTER',
        ),
      );
      c.tick(const Duration(minutes: 3));
      expect(c.elapsed, Duration.zero);
      c.setManualPause(false);
      expect(c.stage, TutorialStage.departure);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.seatbelt,
          1,
          areaId: 'ROW_2_CENTER',
        ),
      );
      expect(c.stage, TutorialStage.arrival);
    },
  );

  test(
    'window initial read and paused position changes do not trigger the puzzle',
    () {
      initialize(c);
      c.start();
      finishDialogue(c);
      for (final seat in CarSeat.values) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.cabinLight, 1, seat: seat),
        );
      }
      finishDialogue(c);
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
      );
      finishDialogue(c);
      expect(c.stage, TutorialStage.windowRequest);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.window,
          20,
          seat: CarSeat.driver,
          initial: true,
        ),
      );
      expect(c.stage, TutorialStage.windowRequest);
      c.setManualPause(true);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.window,
          30,
          seat: CarSeat.driver,
        ),
      );
      c.setManualPause(false);
      expect(c.stage, TutorialStage.windowRequest);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.window,
          20,
          seat: CarSeat.driver,
        ),
      );
      expect(c.stage, TutorialStage.windowCircuit);
      expect(c.windowPositions[CarSeat.driver], 20);
    },
  );

  test(
    'physical light switched off while paused invalidates its old connection',
    () {
      initialize(c);
      c.start();
      finishDialogue(c);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.rearLeft,
        ),
      );
      expect(c.powerCount, 1);
      c.setManualPause(true);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          0,
          seat: CarSeat.rearLeft,
        ),
      );
      c.setManualPause(false);
      expect(c.powerCount, 0);
    },
  );

  test('out-of-range physical window blocks an otherwise aligned circuit', () {
    initialize(c);
    c.stage = TutorialStage.windowCircuit;
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        20,
        seat: CarSeat.driver,
      ),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        75,
        seat: CarSeat.driver,
      ),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        20,
        seat: CarSeat.rearLeft,
      ),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        30,
        seat: CarSeat.rearRight,
      ),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        10,
        seat: CarSeat.passenger,
      ),
    );
    expect(c.connectedGates, 4);
    expect(c.stage, TutorialStage.windowCircuit);
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        20,
        seat: CarSeat.driver,
      ),
    );
    expect(c.stage, TutorialStage.wipers);
  });

  test(
    'native decoder preserves all seat IDs, unknown values, and initial-read flags',
    () {
      final belt = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'seatbelt',
        'area': 'ROW_3_CENTER',
        'value': true,
        'initial': true,
      });
      expect(belt.areaId, 'ROW_3_CENTER');
      expect(belt.initial, isTrue);
      expect(belt.value, 1);
      final unknown = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'seatbelt',
        'area': 'ROW_2_CENTER',
        'value': null,
      });
      expect(unknown.known, isFalse);
      final position = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'window',
        'area': 'ROW_2_LEFT',
        'value': 30.0,
      });
      expect(position.seat, CarSeat.rearLeft);
      expect(position.value, 30);
    },
  );
}
