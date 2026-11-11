import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/game_session.dart';
import 'features/records/record_store.dart';
import 'features/settings/app_settings.dart';
import 'vehicle/device_catalog.dart';
import 'vehicle/fake_vehicle_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    CarscapeApp(
      // ponytail: fake car until the Pleos Kotlin bridge lands; swap here.
      // One decoy is unsupported so the result screen's fallback notice shows.
      vehicle: FakeVehicleService(unsupported: {DeviceId.steeringHeater}),
      session: GameSession(),
      records: RecordStore(prefs),
      settings: AppSettings(prefs),
    ),
  );
}
