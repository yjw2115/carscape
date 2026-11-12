import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'device_catalog.dart';
import 'vehicle_service.dart';

/// The real car through VehicleBridge.kt (Pleos Vehicle SDK). On the Pleos
/// Connect AVD the Virtual Console drives these values.
class PleosVehicleService implements VehicleService {
  static const _methods = MethodChannel('io.carscape/vehicle');

  @override
  Future<bool> isSupported(DeviceId id) async =>
      await _methods.invokeMethod<bool>('isSupported', id.name) ?? false;

  /// One listener per device at a time (one platform stream per channel).
  @override
  Stream<VehicleReading> watch(DeviceId id) => EventChannel(
    'io.carscape/vehicle/${id.name}',
  ).receiveBroadcastStream().map(decode);

  @visibleForTesting
  static VehicleReading decode(dynamic raw) {
    final event = raw as Map;
    final seat = event['seat'] as String?;
    return VehicleReading(
      event['value'] as num,
      seat: seat == null ? null : Seat.values.byName(seat),
    );
  }
}
