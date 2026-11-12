import 'dart:async';
import '../domain/tutorial_models.dart';

/// Integration seam for the entry/vehicle owner. Pass an already normalized,
/// observation stream to TutorialScreen. Story startup can reset puzzle controls.
/// Android's implementation uses the Vehicle SDK. An alternative shared adapter
/// must preserve initial-read flags, door inventory, and actual values.
abstract interface class TutorialInputSource {
  Stream<TutorialVehicleInput> get events;
  Future<void> refresh();
  Future<void> setLightPuzzleActive(bool active);
  Future<void> prepareStoryClimate();
  Future<void> resetReadingLights();
}
