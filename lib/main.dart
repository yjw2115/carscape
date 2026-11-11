import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'core/game_session.dart';
import 'core/theme.dart';
import 'features/entry/mode_select_screen.dart';
import 'vehicle/device_catalog.dart';
import 'vehicle/fake_vehicle_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  // ponytail: fake car until the Pleos Kotlin bridge lands; swap here.
  // One decoy is unsupported so the result screen's fallback notice shows.
  final vehicle = FakeVehicleService(unsupported: {DeviceId.steeringHeater});
  runApp(
    MaterialApp(
      title: 'Carscape',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: ModeSelectScreen(vehicle: vehicle, session: GameSession()),
    ),
  );
}
