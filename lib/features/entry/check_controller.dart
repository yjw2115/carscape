import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/game_session.dart';
import '../../vehicle/device_catalog.dart';
import '../../vehicle/vehicle_service.dart';

const maxAttempts = 3;

/// 2–3 devices the game really uses + decoys, only from [supported], at most
/// 5, shuffled. Fewer than 5 when the car lacks decoys: hiding which devices
/// matter beats a fixed count.
List<DeviceId> planDirectChecks(Set<DeviceId> supported, Random rng) {
  List<DeviceId> pool(bool used) => [
    for (final id in DeviceId.values)
      if (id.checkable && id.usedInGame == used && supported.contains(id)) id,
  ]..shuffle(rng);
  final real = pool(true).take(2 + rng.nextInt(2)).toList();
  final decoys = pool(false).take(5 - real.length);
  return [...real, ...decoys]..shuffle(rng);
}

/// Runs E2 (auto check) → E3/E4 (hands-on check) and writes the results
/// into [session]. Only reads the vehicle.
class CheckController extends ChangeNotifier {
  CheckController(
    this.vehicle,
    this.session, {
    Random? rng,
    this.timeout = const Duration(seconds: 20),
    bool clock = true,
  }) : _rng = rng ?? Random() {
    if (clock) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
    _gearSub = vehicle.watch(DeviceId.gear).listen((r) {
      parked = r.value == gearPark;
      notifyListeners();
    });
  }

  final VehicleService vehicle;
  final GameSession session;
  final Duration timeout;
  final Random _rng;
  Timer? _timer;
  StreamSubscription<VehicleReading>? _gearSub;
  StreamSubscription<VehicleReading>? _deviceSub;

  /// No gear reading yet counts as parked so the check can start.
  bool parked = true;

  int autoDone = 0;
  int get autoTotal => DeviceId.values.length;
  bool get autoFinished => autoDone == autoTotal;
  int get supportedCount =>
      session.devices.values.where((s) => s != DeviceStatus.unsupported).length;

  List<DeviceId> plan = [];
  final Set<DeviceId> skipped = {};
  int index = 0;
  int attempt = 1;
  Duration waited = Duration.zero;
  bool timedOut = false;
  bool detected = false;
  final Map<Seat?, num> _baseline = {};

  bool _started = false;
  bool get finished => _started && index >= plan.length;
  DeviceId? get current => index < plan.length ? plan[index] : null;
  int get verifiedCount =>
      plan.where((id) => session.devices[id] == DeviceStatus.verified).length;

  Future<void> runAutoCheck() async {
    session.devices.clear();
    autoDone = 0;
    notifyListeners();
    for (final id in DeviceId.values) {
      bool ok;
      try {
        ok = await vehicle.isSupported(id);
      } catch (_) {
        ok = false;
      }
      session.devices[id] = ok
          ? DeviceStatus.supported
          : DeviceStatus.unsupported;
      autoDone++;
      notifyListeners();
    }
  }

  void startDirectCheck() {
    // "다시 점검": earlier hands-on results go back to plain supported.
    session.devices.updateAll(
      (_, s) => s == DeviceStatus.unsupported ? s : DeviceStatus.supported,
    );
    final supported = {
      for (final e in session.devices.entries)
        if (e.value == DeviceStatus.supported) e.key,
    };
    _started = true;
    plan = planDirectChecks(supported, _rng);
    skipped.clear();
    index = 0;
    _beginItem();
  }

  void retry() {
    if (!timedOut || attempt >= maxAttempts) return;
    attempt++;
    _arm();
  }

  void proceedWithout() {
    session.devices[current!] = DeviceStatus.fallback;
    _next();
  }

  void skip() {
    skipped.add(current!);
    _next();
  }

  void tick([Duration step = const Duration(seconds: 1)]) {
    if (current == null) return;
    if (detected) return _next();
    if (!parked || timedOut) return;
    waited += step;
    if (waited >= timeout) timedOut = true;
    notifyListeners();
  }

  void _beginItem() {
    attempt = 1;
    _arm();
  }

  void _arm() {
    _deviceSub?.cancel();
    _baseline.clear();
    waited = Duration.zero;
    timedOut = false;
    detected = false;
    final id = current;
    if (id != null) _deviceSub = vehicle.watch(id).listen(_onReading);
    notifyListeners();
  }

  // A change from the value seen when the item started counts as a press.
  // A late signal while the retry window is open still counts.
  void _onReading(VehicleReading r) {
    final base = _baseline[r.seat];
    if (base == null) {
      _baseline[r.seat] = r.value;
      return;
    }
    if (detected || !parked || r.value == base) return;
    detected = true;
    timedOut = false;
    session.devices[current!] = DeviceStatus.verified;
    notifyListeners();
  }

  void _next() {
    _deviceSub?.cancel();
    _deviceSub = null;
    index++;
    _beginItem();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gearSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
