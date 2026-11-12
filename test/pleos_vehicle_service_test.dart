import 'package:carscape/vehicle/device_catalog.dart';
import 'package:carscape/vehicle/pleos_vehicle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes bridge events into readings', () {
    final light = PleosVehicleService.decode({'value': 1, 'seat': 'rearLeft'});
    expect(light.value, 1);
    expect(light.seat, Seat.rearLeft);

    final heater = PleosVehicleService.decode({'value': 27.5, 'seat': null});
    expect(heater.value, 27.5);
    expect(heater.seat, isNull);
  });
}
