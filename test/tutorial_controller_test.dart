import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';

void finishDialogue(TutorialController c) {
  while (c.dialogueActive) {
    c.advanceDialogue();
  }
}

void powerOn(TutorialController c) {
  c.start();
  finishDialogue(c);
  for (final seat in CarSeat.values) {
    c.receive(TutorialVehicleInput(VehicleInputKind.cabinLight, 1, seat: seat));
  }
  finishDialogue(c);
}

void reachCircuit(TutorialController c) {
  powerOn(c);
  c.receive(const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1));
  if (c.stage == TutorialStage.glovebox) {
    c.receive(const TutorialVehicleInput(VehicleInputKind.glovebox, 1));
  }
  finishDialogue(c);
  c.moveWindow(CarSeat.driver, 1);
  finishDialogue(c);
}

void solveCircuit(TutorialController c) {
  const moves = [2, 3, 1, 2];
  for (final seat in CarSeat.values) {
    for (int i = 0; i < moves[seat.index]; i++) {
      c.moveWindow(seat, 1);
    }
  }
}

void main() {
  late TutorialController c;
  setUp(() {
    c = TutorialController(options: const TutorialOptions(enableClock: false));
  });
  tearDown(() {
    c.dispose();
  });

  test('complete requested storyline, with prerequisites enforced', () {
    powerOn(c);
    expect(c.stage, TutorialStage.glovebox);
    c.receive(const TutorialVehicleInput(VehicleInputKind.glovebox, 1));
    expect(c.stage, TutorialStage.glovebox);
    c.receive(const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1));
    c.receive(const TutorialVehicleInput(VehicleInputKind.glovebox, 1));
    finishDialogue(c);
    expect(c.stage, TutorialStage.windowRequest);
    c.moveWindow(CarSeat.passenger, -1);
    expect(c.stage, TutorialStage.windowCircuit);
    finishDialogue(c);
    solveCircuit(c);
    expect(c.stage, TutorialStage.wipers);
    finishDialogue(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
    expect(c.stage, TutorialStage.departure);
    finishDialogue(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.accelerator, 1));
    expect(c.stage, TutorialStage.departure);
    for (final seat in CarSeat.values) {
      c.receive(TutorialVehicleInput(VehicleInputKind.seatbelt, 1, seat: seat));
    }
    // A held accelerator cannot complete the stage when the last belt arrives.
    c.receive(const TutorialVehicleInput(VehicleInputKind.accelerator, 1));
    expect(c.stage, TutorialStage.departure);
    c.receive(const TutorialVehicleInput(VehicleInputKind.accelerator, 0));
    c.receive(const TutorialVehicleInput(VehicleInputKind.accelerator, 1));
    expect(c.stage, TutorialStage.arrival);
    finishDialogue(c);
    expect(c.stage, TutorialStage.result);
    expect(c.result!.windowMoves, 8);
  });

  test(
    'wrong light order resets logical power, repeated sensor values do not',
    () {
      c.start();
      finishDialogue(c);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.rearLeft,
        ),
      );
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.rearLeft,
        ),
      );
      expect(c.powerCount, 1);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.driver,
        ),
      );
      expect(c.powerCount, 0);
      expect(c.lights.values.every((v) => !v), isTrue);
      for (final seat in CarSeat.values) {
        c.receive(
          TutorialVehicleInput(VehicleInputKind.cabinLight, 1, seat: seat),
        );
      }
      expect(c.stage, TutorialStage.glovebox);
    },
  );

  test('unsupported glovebox sensor never blocks the game', () {
    final fallback = TutorialController(
      options: const TutorialOptions(
        enableClock: false,
        gloveboxSensorAvailable: false,
      ),
    );
    addTearDown(fallback.dispose);
    powerOn(fallback);
    fallback.receive(
      const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
    );
    expect(fallback.stage, TutorialStage.windowRequest);
  });

  test(
    'four different gates required, bounded windows, reversible moves, reset',
    () {
      reachCircuit(c);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.window,
          75,
          seat: CarSeat.driver,
        ),
      );
      expect(c.windowPositions[CarSeat.driver], 0);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.window,
          9,
          seat: CarSeat.driver,
        ),
      );
      expect(c.windowMoves, 0);
      c.moveWindow(CarSeat.rearLeft, 1);
      c.moveWindow(CarSeat.rearLeft, 1);
      expect(c.connectedGates, 1);
      c.moveWindow(CarSeat.rearLeft, -1);
      expect(c.connectedGates, 0);
      c.resetCircuit();
      expect(c.circuitTouched, isEmpty);
      expect(c.circuitOffsets, TutorialController.initialOffsets);
      solveCircuit(c);
      expect(c.stage, TutorialStage.wipers);
    },
  );

  test('circuit has exactly one solution in safe window range', () {
    final solutions = <List<int>>[];
    for (int a = 0; a <= 5; a++) {
      for (int b = 0; b <= 5; b++) {
        for (int d = 0; d <= 5; d++) {
          for (int e = 0; e <= 5; e++) {
            final moves = [a, b, d, e];
            c.circuitOffsets.setAll(
              0,
              List.generate(
                4,
                (i) => TutorialController.initialOffsets[i] + moves[i],
              ),
            );
            if (c.connectedGates == 4) solutions.add(moves);
          }
        }
      }
    }
    expect(solutions, [
      [2, 3, 1, 2],
    ]);
  });

  test(
    'parking, disconnection, manual pause and background stop input and time',
    () {
      c.start();
      finishDialogue(c);
      c.tick(const Duration(seconds: 10));
      expect(c.elapsed.inSeconds, 10);
      c.setManualPause(true);
      c.tick(const Duration(seconds: 30));
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.rearLeft,
        ),
      );
      expect(c.powerCount, 0);
      expect(c.elapsed.inSeconds, 10);
      c.setManualPause(false);
      c.setBackground(true);
      c.tick(const Duration(seconds: 15));
      c.setBackground(false);
      for (final kind in [
        VehicleInputKind.parking,
        VehicleInputKind.connection,
      ]) {
        c.receive(TutorialVehicleInput(kind, 0));
        c.tick(const Duration(seconds: 20));
        c.receive(
          const TutorialVehicleInput(
            VehicleInputKind.cabinLight,
            1,
            seat: CarSeat.rearLeft,
          ),
        );
        expect(c.powerCount, 0);
        c.receive(TutorialVehicleInput(kind, 1));
      }
      expect(c.elapsed.inSeconds, 10);
      c.tick(const Duration(seconds: 5));
      expect(c.elapsed.inSeconds, 15);
    },
  );

  test(
    'dialogue gates inputs; hint count, three levels, score and idle help',
    () {
      c.start();
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.cabinLight,
          1,
          seat: CarSeat.rearLeft,
        ),
      );
      c.useHint();
      expect(c.hintsUsed, 0);
      finishDialogue(c);
      c.tick(const Duration(seconds: 46));
      expect(c.showIdleHelp, isTrue);
      for (int i = 0; i < 5; i++) {
        c.useHint();
      }
      expect(c.hintsUsed, 3);
      expect(c.canHint, isFalse);
      expect(c.hintLevel, 3);
      final score = TutorialResult(
        playTime: c.elapsed,
        hintsUsed: c.hintsUsed,
        windowMoves: 0,
      );
      expect(score.recordedTime, const Duration(seconds: 226));
    },
  );
}
