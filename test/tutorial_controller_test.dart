import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/domain/tutorial_script.dart';
import 'package:carscape/features/tutorial/presentation/tutorial_atmosphere.dart';

TutorialController controller() =>
    TutorialController(options: const TutorialOptions(enableClock: false));
void dialogue(TutorialController c) {
  while (c.dialogueActive) {
    c.advanceDialogue();
  }
}

void runFor(TutorialController c, double seconds) {
  for (int i = 0; i < (seconds * 10).round(); i++) {
    c.tick(const Duration(milliseconds: 100));
  }
}

void light(
  TutorialController c,
  CarSeat seat,
  bool on, {
  bool initial = false,
}) => c.receive(
  TutorialVehicleInput(
    VehicleInputKind.cabinLight,
    on ? 1 : 0,
    seat: seat,
    initial: initial,
  ),
);
void window(TutorialController c, CarSeat seat, num value) =>
    c.receive(TutorialVehicleInput(VehicleInputKind.window, value, seat: seat));
void toVentilation(TutorialController c) {
  c.start();
  dialogue(c);
  for (final seat in CarSeat.values) {
    light(c, seat, true);
  }
  dialogue(c);
  c.receive(const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1));
  c.receive(const TutorialVehicleInput(VehicleInputKind.glovebox, 1));
  dialogue(c);
}

void toEscape(TutorialController c) {
  toVentilation(c);
  for (final seat in CarSeat.values) {
    window(c, seat, 20);
  }
  runFor(c, 6);
  dialogue(c);
}

void main() {
  test(
    'complete four chapters with all windows, clear vision, then right steering',
    () {
      final c = controller();
      addTearDown(c.dispose);
      toEscape(c);
      expect(c.stage, TutorialStage.escape);
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 45));
      runFor(c, 5);
      expect(c.stage, TutorialStage.escape);
      c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
      runFor(c, 3.2);
      expect(c.shelterVisible, isTrue);
      expect(c.stage, TutorialStage.escape); // An old right turn cannot finish.
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 0));
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, -45));
      expect(c.stage, TutorialStage.escape);
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 31));
      expect(c.stage, TutorialStage.arrival);
      dialogue(c);
      expect(c.result, isNotNull);
      expect(c.result!.windowMoves, 4);
      expect(c.result!.usedTestNavigation, isFalse);
    },
  );
  test(
    'light order is rear left, rear right, driver, passenger; error resets',
    () {
      final c = controller();
      addTearDown(c.dispose);
      c.start();
      dialogue(c);
      light(c, CarSeat.rearLeft, true);
      light(c, CarSeat.rearLeft, true);
      expect(c.powerCount, 1);
      light(c, CarSeat.passenger, true);
      expect(c.powerCount, 0);
      for (final seat in CarSeat.values) {
        light(c, seat, true);
      }
      expect(c.stage, TutorialStage.glovebox);
    },
  );
  test('heat alone completes when glovebox sensor is unavailable', () {
    final c = TutorialController(
      options: const TutorialOptions(
        enableClock: false,
        gloveboxSensorAvailable: false,
      ),
    );
    addTearDown(c.dispose);
    c.start();
    dialogue(c);
    for (final seat in CarSeat.values) {
      light(c, seat, true);
    }
    dialogue(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1));
    expect(c.stage, TutorialStage.ventilation);
    expect(c.currentLine!.text, contains('가스가 새어나오잖아'));
    expect(
      TutorialScript.dialogue.values
          .expand((v) => v)
          .any((v) => v.text.contains('눈이 쌓여서 아무것도')),
      isFalse,
    );
  });
  test('opening cost calibration matches requested tradeoff', () {
    expect(
      [
        20,
        40,
        60,
        80,
        100,
      ].map((p) => TutorialController.windowColdCost(p.toDouble())),
      [1, 5, 10, 15, 20],
    );
  });
  test('one fully open window cannot solve gas stage even with time', () {
    final c = controller();
    addTearDown(c.dispose);
    toVentilation(c);
    window(c, CarSeat.driver, 100);
    runFor(c, 60);
    expect(c.gasLevel, 0);
    expect(c.cabinTemperature, lessThan(16));
    expect(c.stage, TutorialStage.ventilation);
    expect(c.frost, greaterThan(.9));
    window(c, CarSeat.driver, 20);
    for (final seat in [CarSeat.rearLeft, CarSeat.rearRight]) {
      window(c, seat, 20);
    }
    runFor(c, 30);
    expect(c.stage, TutorialStage.ventilation);
    window(c, CarSeat.passenger, 20);
    runFor(c, 6);
    expect(c.stage, TutorialStage.escape);
  });
  test('cabin openings gradually clear gas, chill, and prevent completion', () {
    final c = controller();
    addTearDown(c.dispose);
    toVentilation(c);
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 1, areaId: 'REAR'),
    );
    expect(c.gasLevel, 100);
    runFor(c, 1);
    expect(c.gasLevel, 75);
    runFor(c, 4);
    expect(c.cabinTemperature, 10);
    expect(c.gasLevel, 0);
    expect(c.frost, greaterThan(.3));
    expect(c.ambientRevision, 1);
    expect(c.stage, TutorialStage.ventilation);
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 0, areaId: 'REAR'),
    );
    runFor(c, 5);
    expect(c.gasLevel, 100);
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.door,
        1,
        areaId: 'ROW_1_LEFT',
      ),
    );
    expect(c.gasLevel, 100);
    runFor(c, 2);
    expect(c.gasLevel, 50);
    expect(c.cabinTemperature, 10);
    expect(c.stage, TutorialStage.ventilation);
    expect(c.ambientRevision, 1);
    for (final seat in CarSeat.values) {
      window(c, seat, 20);
    }
    runFor(c, 5);
    expect(c.gasLevel, 0);
    expect(c.cabinTemperature, 6);
    expect(c.stage, TutorialStage.ventilation);
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.door,
        0,
        areaId: 'ROW_1_LEFT',
      ),
    );
    runFor(c, 7);
    expect(c.stage, TutorialStage.escape);
  });
  test(
    'normal chapter clears wait for the audio cue before the next story',
    () {
      final c = TutorialController(
        options: const TutorialOptions(
          enableClock: false,
          waitForChapterClear: true,
        ),
      );
      addTearDown(c.dispose);
      c.start();
      dialogue(c);
      for (final seat in CarSeat.values) {
        light(c, seat, true);
      }
      expect(c.pendingChapter, TutorialStage.glovebox);
      expect(c.stage, TutorialStage.power);
      expect(c.acceptsInput, isFalse);
      c.finishChapterClear(TutorialStage.glovebox);
      expect(c.stage, TutorialStage.glovebox);
      expect(c.dialogueActive, isTrue);
      dialogue(c);
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
      );
      c.receive(const TutorialVehicleInput(VehicleInputKind.glovebox, 1));
      expect(c.pendingChapter, TutorialStage.ventilation);
      c.finishChapterClear(TutorialStage.ventilation);
      dialogue(c);
      for (final seat in CarSeat.values) {
        window(c, seat, 20);
      }
      runFor(c, 6);
      expect(c.pendingChapter, TutorialStage.escape);
      expect(c.stage, TutorialStage.ventilation);
      c.finishChapterClear(TutorialStage.escape);
      expect(c.stage, TutorialStage.escape);
      expect(c.dialogueActive, isTrue);
    },
  );
  test('40 percent opening is too cold, correcting to 20 each recovers', () {
    final c = controller();
    addTearDown(c.dispose);
    toVentilation(c);
    for (final seat in CarSeat.values) {
      window(c, seat, 20);
    }
    window(c, CarSeat.driver, 40);
    runFor(c, 6);
    expect(c.stage, TutorialStage.ventilation);
    window(c, CarSeat.driver, 20);
    runFor(c, 6);
    expect(c.stage, TutorialStage.escape);
  });
  test('pause stops game meters, clock, and wiper clearing', () {
    final c = controller();
    addTearDown(c.dispose);
    toVentilation(c);
    window(c, CarSeat.driver, 40);
    final elapsed = c.elapsed;
    c.setManualPause(true);
    runFor(c, 20);
    expect(c.elapsed, elapsed);
    expect(c.gasLevel, 100);
    expect(c.frost, 0);
    c.setManualPause(false);
    runFor(c, 2);
    expect(c.frost, greaterThan(0));
  });
  test('hint cost and notes clock policy; test navigation marks result', () {
    final c = controller();
    addTearDown(c.dispose);
    c.start();
    dialogue(c);
    c.useHint();
    c.useHint();
    c.testNavigate(1);
    expect(c.stage, TutorialStage.glovebox);
    c.testNavigate(1);
    expect(c.stage, TutorialStage.ventilation);
    c.testNavigate(-1);
    expect(c.stage, TutorialStage.glovebox);
    c.testNavigate(1);
    c.testNavigate(1);
    c.testNavigate(1);
    dialogue(c);
    expect(c.stage, TutorialStage.result);
    expect(c.result!.usedTestNavigation, isTrue);
    expect(
      c.result!.recordedTime - c.result!.playTime,
      const Duration(minutes: 2),
    );
  });

  test('a wheel already turned right must still turn a little further', () {
    final c = controller();
    addTearDown(c.dispose);
    toEscape(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 40));
    c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
    runFor(c, 3.2);
    expect(c.shelterVisible, isTrue);
    expect(c.stage, TutorialStage.escape);
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 43));
    expect(c.stage, TutorialStage.escape); // Less than the 5° change.
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 46));
    expect(c.stage, TutorialStage.arrival);
  });

  test('turning left first moves the base; then a small right turn wins', () {
    final c = controller();
    addTearDown(c.dispose);
    toEscape(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
    runFor(c, 3.2);
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, -20));
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, -16));
    expect(c.stage, TutorialStage.escape);
    c.receive(const TutorialVehicleInput(VehicleInputKind.steering, -14));
    expect(c.stage, TutorialStage.arrival);
  });

  test('front defroster melts some snow but never clears the view', () {
    final c = controller();
    addTearDown(c.dispose);
    toEscape(c);
    c.receive(const TutorialVehicleInput(VehicleInputKind.frontDefroster, 1));
    runFor(c, 20);
    expect(c.melt, closeTo(TutorialController.maxMelt, 1e-9));
    expect(c.visibility, 0);
    expect(c.shelterVisible, isFalse);
    c.receive(const TutorialVehicleInput(VehicleInputKind.frontDefroster, 0));
    expect(c.defrosterOn, isFalse);
  });

  test('gas reading is red from 70% and green near 0%', () {
    int argb(double level) => gasColor(level).toARGB32();
    expect(argb(100), 0xFFFF4E3E);
    expect(argb(85), 0xFFFF4E3E);
    expect(argb(70), 0xFFFF4E3E);
    expect(argb(52), 0xFFFF9B3D);
    expect(argb(32), 0xFFFFDA4D);
    expect(argb(5), 0xFF6FDB8F);
  });
}
