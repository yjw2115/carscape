import 'dart:async';
import 'device_catalog.dart';
import 'vehicle_service.dart';

/// In-memory car for developing on Windows/Chrome. [set] stands in for the
/// player pressing a real button.
class FakeVehicleService implements VehicleService {
  FakeVehicleService({Set<DeviceId> unsupported = const {}})
    : unsupported = {...unsupported};

  final Set<DeviceId> unsupported;
  final _changes = StreamController<(DeviceId, VehicleReading)>.broadcast();
  final Map<DeviceId, Map<Seat?, num>> _values = {
    for (final id in DeviceId.values)
      id: id.perSeat ? {for (final s in Seat.values) s: 0} : {null: 0},
  }..[DeviceId.gear] = {null: gearPark};

  num value(DeviceId id, [Seat? seat]) =>
      _values[id]![id.perSeat ? seat ?? Seat.driver : null]!;

  void set(DeviceId id, num value, {Seat? seat}) {
    final key = id.perSeat ? seat ?? Seat.driver : null;
    _values[id]![key] = value;
    _changes.add((id, VehicleReading(value, seat: key)));
  }

  @override
  Future<bool> isSupported(DeviceId id) async => !unsupported.contains(id);

  @override
  Stream<VehicleReading> watch(DeviceId id) async* {
    for (final e in _values[id]!.entries) {
      yield VehicleReading(e.value, seat: e.key);
    }
    yield* _changes.stream.where((c) => c.$1 == id).map((c) => c.$2);
  }
}
