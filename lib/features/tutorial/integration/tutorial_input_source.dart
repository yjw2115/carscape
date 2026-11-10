import 'dart:async';
import '../domain/tutorial_models.dart';

/// Integration seam for the entry/vehicle owner. Pass an already normalized,
/// read-only stream to TutorialScreen. No shared device catalog is invented.
/// Android's implementation uses the Vehicle SDK. An alternative shared adapter
/// must preserve initial-read flags, capability seat inventory, and actual values.
abstract interface class TutorialInputSource {
  Stream<TutorialVehicleInput> get events;
  Future<void> refresh();
}
