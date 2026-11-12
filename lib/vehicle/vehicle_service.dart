import 'device_catalog.dart';

class VehicleReading {
  const VehicleReading(this.value, {this.seat});
  final num value;

  /// Null for devices that aren't [DeviceId.perSeat].
  final Seat? seat;
}

/// Read-only access to the car. The app never controls the vehicle.
/// Implementations: FakeVehicleService (Windows/Chrome), PleosVehicleService.
abstract interface class VehicleService {
  /// `check…Capabilities` on Pleos.
  Future<bool> isSupported(DeviceId id);

  /// Emits the current value (one per seat for per-seat devices), then every
  /// change. `get…` + `register…` on Pleos.
  Stream<VehicleReading> watch(DeviceId id);
}
