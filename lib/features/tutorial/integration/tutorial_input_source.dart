import 'dart:async';
import '../domain/tutorial_models.dart';

/// Integration seam for the entry/vehicle owner. Pass an already normalized,
/// read-only stream to TutorialScreen. No shared device catalog is invented.
/// Physical accelerator and per-seat cabin light support must be established
/// by that adapter; this preview makes no claim of Pleos hardware integration.
abstract interface class TutorialInputSource {
  Stream<TutorialVehicleInput> get events;
}
