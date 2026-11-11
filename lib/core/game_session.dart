import '../vehicle/device_catalog.dart';

/// Per-device result of the vehicle check (team-wide rule, CLAUDE.md).
enum DeviceStatus {
  /// Auto check: the car reports the device. Not tried by hand.
  supported,

  /// Auto check: the car doesn't have it → screen touch replaces it.
  unsupported,

  /// Hands-on check: the player pressed it and the app saw the change.
  verified,

  /// Hands-on check failed and the player chose "이 장치 없이 진행"
  /// → screen touch replaces it.
  fallback,
}

/// Game-wide state that the tutorial and scenarios read.
class GameSession {
  final Map<DeviceId, DeviceStatus> devices = {};

  /// False → the scenario must use its on-screen touch alternative.
  /// Not checked yet → assume usable (the check is optional).
  bool canUse(DeviceId id) =>
      devices[id] == null ||
      devices[id] == DeviceStatus.supported ||
      devices[id] == DeviceStatus.verified;
}
