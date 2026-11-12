import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/integration/pleos_tutorial_input_source.dart';
import 'tutorial_controller_test.dart' show dialogue, runFor, light, window;

TutorialController liveController() {
  final c = TutorialController(
    options: const TutorialOptions(enableClock: false),
  );
  c.enableVehicleMode();
  c.receive(
    const TutorialVehicleInput(
      VehicleInputKind.configuration,
      0,
      data: {
        'doors': [
          'ROW_1_LEFT',
          'ROW_1_RIGHT',
          'ROW_2_LEFT',
          'ROW_2_RIGHT',
          'REAR',
          'HOOD',
        ],
        'lightControl': true,
        'gloveboxOpen': false,
      },
    ),
  );
  c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 1));
  c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 1));
  c.receive(
    const TutorialVehicleInput(
      VehicleInputKind.passengerHeater,
      0,
      initial: true,
    ),
  );
  c.receive(
    const TutorialVehicleInput(VehicleInputKind.wiper, 0, initial: true),
  );
  for (final seat in CarSeat.values) {
    light(c, seat, false, initial: true);
    c.receive(
      TutorialVehicleInput(
        VehicleInputKind.window,
        0,
        seat: seat,
        initial: true,
      ),
    );
  }
  for (final id in c.doors.keys.toList()) {
    c.receive(
      TutorialVehicleInput(VehicleInputKind.door, 0, areaId: id, initial: true),
    );
  }
  return c;
}

void main() {
  test(
    'preexisting lights reset on entry; count waits for physical reset acknowledgment',
    () {
      final c = liveController();
      addTearDown(c.dispose);
      light(c, CarSeat.driver, true, initial: true);
      c.start();
      dialogue(c);
      expect(c.lightsResetting, isTrue);
      final revision = c.lightResetRevision;
      light(c, CarSeat.rearLeft, true);
      expect(c.powerCount, 0);
      c.confirmLightReset(revision, success: true);
      light(c, CarSeat.rearLeft, true);
      expect(c.powerCount, 1);
      light(c, CarSeat.passenger, true);
      expect(c.powerCount, 0);
      expect(c.lightsResetting, isTrue);
      final second = c.lightResetRevision;
      c.confirmLightReset(revision, success: true);
      expect(c.lightsResetting, isTrue);
      c.confirmLightReset(second, success: true);
      for (final seat in CarSeat.values) {
        light(c, seat, true);
      }
      expect(c.stage, TutorialStage.glovebox);
    },
  );
  test('failed reset blocks progress; explicit retry can recover', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.start();
    dialogue(c);
    c.confirmLightReset(c.lightResetRevision, success: false);
    expect(c.paused, isTrue);
    expect(c.lightsResetting, isTrue);
    c.retryLightReset();
    c.confirmLightReset(c.lightResetRevision, success: true);
    expect(c.paused, isFalse);
    expect(c.lightsResetting, isFalse);
  });
  test('a wrong light switched while paused resets after resume', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.start();
    dialogue(c);
    c.confirmLightReset(c.lightResetRevision, success: true);
    c.setManualPause(true);
    light(c, CarSeat.passenger, true);
    c.setManualPause(false);
    expect(c.lightsResetting, isTrue);
  });
  test('unknown door or window cannot produce a successful gas stage', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.testNavigate(1);
    c.testNavigate(1);
    c.testNavigate(1);
    dialogue(c);
    for (final seat in CarSeat.values) {
      window(c, seat, 20);
    }
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.door,
        0,
        areaId: 'REAR',
        known: false,
      ),
    );
    runFor(c, 20);
    expect(c.stage, TutorialStage.ventilation);
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 0, areaId: 'REAR'),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        0,
        seat: CarSeat.driver,
        known: false,
      ),
    );
    runFor(c, 20);
    expect(c.stage, TutorialStage.ventilation);
    window(c, CarSeat.driver, 20);
    runFor(c, 6);
    expect(c.stage, TutorialStage.escape);
  });
  test('frunk state and sensor errors are irrelevant to ventilation', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.testNavigate(1);
    c.testNavigate(1);
    c.testNavigate(1);
    dialogue(c);
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 1, areaId: 'HOOD'),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.issue,
        0,
        data: {'feature': 'door:HOOD', 'message': 'Unavailable'},
      ),
    );
    runFor(c, 5);
    expect(c.gasLevel, 100);
    expect(c.cabinTemperature, 20);
    expect(c.ambientRevision, 0);
    expect(c.paused, isFalse);
    for (final seat in CarSeat.values) {
      window(c, seat, 20);
    }
    runFor(c, 6);
    expect(c.stage, TutorialStage.escape);
  });
  test(
    'pre-existing heater, balanced windows and wiper need fresh actions',
    () {
      final c = liveController();
      addTearDown(c.dispose);
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
      );
      c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
      for (final seat in CarSeat.values) {
        window(c, seat, 20);
      }
      c.testNavigate(1);
      c.testNavigate(1);
      dialogue(c);
      expect(c.stage, TutorialStage.glovebox);
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
      );
      expect(c.stage, TutorialStage.glovebox);
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 0),
      );
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.passengerHeater, 1),
      );
      expect(c.stage, TutorialStage.ventilation);
      dialogue(c);
      runFor(c, 7);
      expect(c.gasLevel, 0);
      expect(c.stage, TutorialStage.ventilation);
      window(c, CarSeat.driver, 0);
      window(c, CarSeat.driver, 20);
      runFor(c, 6);
      expect(c.stage, TutorialStage.escape);
      dialogue(c);
      runFor(c, 4);
      expect(c.visibility, 0);
      c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 0));
      c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
      runFor(c, 4);
      expect(c.shelterVisible, isTrue);
    },
  );
  test('physical changes continue caching under narration and pause', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.testNavigate(1);
    c.testNavigate(1);
    c.testNavigate(1);
    expect(c.dialogueActive, isTrue);
    for (final seat in CarSeat.values) {
      window(c, seat, 20);
    }
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 1, areaId: 'REAR'),
    );
    dialogue(c);
    runFor(c, 6);
    expect(c.stage, TutorialStage.ventilation);
    c.setManualPause(true);
    c.receive(
      const TutorialVehicleInput(VehicleInputKind.door, 0, areaId: 'REAR'),
    );
    runFor(c, 10);
    expect(c.stage, TutorialStage.ventilation);
    c.setManualPause(false);
    runFor(c, 7);
    expect(c.stage, TutorialStage.escape);
  });
  test('P gear and connection suspend the new stages', () {
    final c = liveController();
    addTearDown(c.dispose);
    c.testNavigate(1);
    c.testNavigate(1);
    c.testNavigate(1);
    dialogue(c);
    window(c, CarSeat.driver, 100);
    c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 0));
    runFor(c, 10);
    expect(c.cabinTemperature, 20);
    c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 1));
    c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 0));
    runFor(c, 10);
    expect(c.cabinTemperature, 20);
    c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 1));
    runFor(c, 2);
    expect(c.cabinTemperature, lessThan(16));
  });
  test(
    'steering initial value and early turn never skip the visibility requirement',
    () {
      final c = liveController();
      addTearDown(c.dispose);
      for (int i = 0; i < 4; i++) {
        c.testNavigate(1);
      }
      dialogue(c);
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.steering,
          45,
          initial: true,
        ),
      );
      c.receive(const TutorialVehicleInput(VehicleInputKind.wiper, 1));
      runFor(c, 3.2);
      expect(c.shelterVisible, isTrue);
      expect(c.stage, TutorialStage.escape);
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 0));
      c.receive(
        const TutorialVehicleInput(
          VehicleInputKind.steering,
          45,
          initial: true,
        ),
      );
      expect(c.stage, TutorialStage.escape);
      c.receive(const TutorialVehicleInput(VehicleInputKind.steering, 46));
      expect(c.stage, TutorialStage.arrival);
    },
  );
  test(
    'decoder preserves fractional window values, unknown doors, steering signs',
    () {
      final window = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'window',
        'value': 20.0,
        'area': 'ROW_1_LEFT',
        'initial': true,
      });
      expect(window.seat, CarSeat.driver);
      expect(window.initial, isTrue);
      final door = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'door',
        'value': null,
        'area': 'REAR',
      });
      expect(door.known, isFalse);
      expect(door.areaId, 'REAR');
      final steering = PleosTutorialInputSource.decode({
        'type': 'value',
        'kind': 'steering',
        'value': -30.0,
      });
      expect(steering.value, -30);
    },
  );
}
