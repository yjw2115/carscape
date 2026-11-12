import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/core/game_session.dart';
import 'package:carscape/features/entry/check_controller.dart';
import 'package:carscape/vehicle/device_catalog.dart';
import 'package:carscape/vehicle/fake_vehicle_service.dart';

Future<CheckController> ready(FakeVehicleService car, {int seed = 1}) async {
  final c = CheckController(
    car,
    GameSession(),
    rng: Random(seed),
    clock: false,
  );
  await c.runAutoCheck();
  c.startDirectCheck();
  await pumpEventQueue();
  return c;
}

void main() {
  test(
    'plan: 2–3 used devices + decoys, only supported, never conspicuous',
    () {
      final all = DeviceId.values.toSet();
      for (var seed = 0; seed < 200; seed++) {
        final plan = planDirectChecks(all, Random(seed));
        final real = plan.where((d) => d.usedInGame).length;
        expect(plan.length, 5);
        expect(plan.toSet().length, 5);
        expect(real, inInclusiveRange(2, 3));
        expect(plan.every((d) => d.checkable), isTrue);
      }
      final noDecoys = planDirectChecks({
        DeviceId.cabinLight,
        DeviceId.steering,
        DeviceId.window,
      }, Random(0));
      expect(noDecoys.toSet(), {DeviceId.cabinLight, DeviceId.steering});
    },
  );

  test(
    'auto check marks unsupported devices and keeps them out of the plan',
    () async {
      final c = await ready(
        FakeVehicleService(
          unsupported: {DeviceId.recirculation, DeviceId.passengerHeater},
        ),
      );
      expect(
        c.session.devices[DeviceId.passengerHeater],
        DeviceStatus.unsupported,
      );
      expect(c.session.canUse(DeviceId.passengerHeater), isFalse);
      expect(c.plan, isNot(contains(DeviceId.recirculation)));
      expect(c.supportedCount, DeviceId.values.length - 2);
    },
  );

  test(
    'a change from the start value verifies; retries end in fallback',
    () async {
      final car = FakeVehicleService();
      final c = await ready(car);
      final first = c.current!;
      car.set(first, 1);
      await pumpEventQueue();
      expect(c.session.devices[first], DeviceStatus.verified);
      c.tick();
      expect(c.index, 1);

      final second = c.current!;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        c.tick(const Duration(seconds: 20));
        expect(c.timedOut, isTrue);
        expect(c.attempt, attempt);
        c.retry();
      }
      expect(c.attempt, maxAttempts, reason: 'no 4th attempt');
      c.proceedWithout();
      expect(c.session.devices[second], DeviceStatus.fallback);
      expect(c.session.canUse(second), isFalse);

      while (!c.finished) {
        c.skip();
      }
      expect(c.verifiedCount, 1);

      c.startDirectCheck();
      expect(
        c.session.devices[first],
        DeviceStatus.supported,
        reason: '다시 점검 resets',
      );
    },
  );

  test('not in P: timer stops and presses are ignored', () async {
    final car = FakeVehicleService();
    final c = await ready(car);
    car.set(DeviceId.gear, 0);
    await pumpEventQueue();
    c.tick(const Duration(seconds: 30));
    expect(c.timedOut, isFalse);
    car.set(c.current!, 1);
    await pumpEventQueue();
    expect(c.detected, isFalse);
  });
}
