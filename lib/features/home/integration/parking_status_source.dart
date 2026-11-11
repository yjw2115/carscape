import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ParkingState { checking, parked, notParked }

/// Gear state for the home screen. Listening starts vehicle monitoring and
/// cancelling stops it.
abstract interface class ParkingStatusSource {
  Stream<ParkingState> watch();
}

/// Browser and desktop previews have no vehicle, so they are always parked.
class PreviewParkingStatusSource implements ParkingStatusSource {
  const PreviewParkingStatusSource();

  @override
  Stream<ParkingState> watch() => Stream.value(ParkingState.parked);
}

/// Reads the gear through the shared Android vehicle bridge
/// (TutorialVehicleBridge.kt). The bridge serves one listener at a time, so
/// the home screen must cancel before another screen starts listening.
class PleosParkingStatusSource implements ParkingStatusSource {
  const PleosParkingStatusSource();

  static const _events = EventChannel('io.carscape/tutorial_vehicle/events');

  @override
  Stream<ParkingState> watch() => _events
      .receiveBroadcastStream()
      .map(decode)
      .where((state) => state != null)
      .cast<ParkingState>();

  /// Unknown or failed gear reads fail closed as [ParkingState.checking].
  @visibleForTesting
  static ParkingState? decode(dynamic raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type == 'connection' && raw['value'] != true) {
      return ParkingState.checking;
    }
    if (type == 'issue' && raw['feature'] == 'parking') {
      return ParkingState.checking;
    }
    if (type == 'value' && raw['kind'] == 'parking') {
      final value = raw['value'];
      if (value == null) return ParkingState.checking;
      return value == true ? ParkingState.parked : ParkingState.notParked;
    }
    return null;
  }
}

ParkingStatusSource defaultParkingStatusSource() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? const PleosParkingStatusSource()
    : const PreviewParkingStatusSource();
