import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/tutorial_models.dart';
import 'tutorial_input_source.dart';

/// Vehicle SDK observations, plus chapter-scoped reading-light OFF reset.
class PleosTutorialInputSource implements TutorialInputSource {
  static const _events = EventChannel('io.carscape/tutorial_vehicle/events');
  static const _methods = MethodChannel('io.carscape/tutorial_vehicle');

  @override
  Stream<TutorialVehicleInput> get events =>
      _events.receiveBroadcastStream().map(decode);

  static TutorialVehicleInput decode(dynamic raw) {
    final event = Map<String, Object?>.from(raw as Map);
    if (event['type'] == 'capabilities') {
      return TutorialVehicleInput(
        VehicleInputKind.configuration,
        0,
        data: Map<String, Object?>.from(event['data'] as Map),
      );
    }
    if (event['type'] == 'issue') {
      return TutorialVehicleInput(VehicleInputKind.issue, 0, data: event);
    }
    if (event['type'] == 'connection') {
      return TutorialVehicleInput(
        VehicleInputKind.connection,
        event['value'] == true ? 1 : 0,
      );
    }
    final kind = VehicleInputKind.values.byName(event['kind'] as String);
    final value = event['value'];
    final area = event['area'] as String?;
    return TutorialVehicleInput(
      kind,
      value is num
          ? value
          : value == true
          ? 1
          : 0,
      seat: seatForArea(area),
      areaId: area,
      initial: event['initial'] == true,
      known: value != null,
    );
  }

  @override
  Future<void> refresh() async {
    await _methods.invokeMethod<void>('refresh');
  }

  @override
  Future<void> setLightPuzzleActive(bool active) =>
      _methods.invokeMethod<void>('setLightPuzzleActive', active);

  @override
  Future<void> resetReadingLights() =>
      _methods.invokeMethod<void>('resetReadingLights');
}
