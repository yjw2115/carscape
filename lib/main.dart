import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'core/game_session.dart';
import 'core/theme.dart';
import 'features/entry/check_intro_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'vehicle/device_catalog.dart';
import 'vehicle/fake_vehicle_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  // ponytail: fake car until the Pleos Kotlin bridge lands; swap here.
  // One decoy is unsupported so the result screen's fallback notice shows.
  final vehicle = FakeVehicleService(unsupported: {DeviceId.steeringHeater});
  final session = GameSession();
  runApp(
    MaterialApp(
      title: 'Carscape',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      // Home is the first screen; its "차량 점검" button opens E2–E5.
      home: HomeScreen(
        openVehicleCheck: (context) =>
            openVehicleCheck(context, vehicle, session),
      ),
    ),
  );
}
