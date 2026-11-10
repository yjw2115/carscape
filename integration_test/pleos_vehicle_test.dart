// Runs only against the local Pleos AVD. Keep its Virtual Console browser open.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/integration/narration_player.dart';
import 'package:carscape/features/tutorial/presentation/tutorial_screen.dart';
import 'package:carscape/features/tutorial/presentation/tutorial_style.dart';

class _Captions implements NarrationPlayer {
  @override
  Future<bool> speak(String text) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual SDK: light OFF reset, ventilation hazards, wipe then turn right to finish',
    (tester) async {
      final c = TutorialController();
      final http = HttpClient();
      Future<void> put(String path, Map<String, String> query) async {
        final request = await http.putUrl(
          Uri.http('127.0.0.1:8088', path, query),
        );
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();
        expect(response.statusCode, 200, reason: body);
        expect(
          body,
          isNot(contains('emulator_inactive')),
          reason: 'Keep the console browser open',
        );
      }

      Future<void> until(bool Function() predicate, String label) async {
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (!predicate()) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              '$label: ${c.stage}, ${c.vehicleIssues}, ${c.vehicleCapabilities}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
      }

      Future<void> dialogue() async {
        while (c.dialogueActive) {
          await until(() => !c.paused, 'Narration paused');
          final next = find.byKey(const Key('next-dialogue'));
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      var converted = false;
      Future<void> capture(String name) async {
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        // Let the test binding's pointer crosshairs fade before exporting frames.
        for (int i = 0; i < 8; i++) {
          for (final view in binding.renderViews) {
            view.markNeedsPaint();
          }
          await tester.pump(const Duration(milliseconds: 20));
        }
        await binding.takeScreenshot(name);
      }

      Future<void> assertActualLightsOff() async {
        final diagnostic = await const MethodChannel(
          'io.carscape/tutorial_vehicle',
        ).invokeMapMethod<String, dynamic>('diagnostics');
        final values = Map<String, dynamic>.from(diagnostic!['values'] as Map);
        for (final seat in CarSeat.values) {
          expect(values['cabinLight:${areaForSeat(seat)}'], false);
        }
        final request = await http.getUrl(
          Uri.http('127.0.0.1:8088', '/vehicle/state'),
        );
        final response = await request.close();
        final state =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;
        expect(
          (state['body']['reading_lights'] as Map).values.every(
            (v) => v == false,
          ),
          isTrue,
          reason: 'Console state must reflect the OFF reset too',
        );
      }

      Future<void> resetFixture() async {
        await put('/vehicle/gear', {'gear': 'Park'});
        await put('/vehicle/controls', {'steering': '0'});
        await put('/vehicle/body', {
          'door_fl': 'false',
          'door_fr': 'false',
          'door_rl': 'false',
          'door_rr': 'false',
          'trunk': 'false',
          'frunk': 'false',
          'window_fl': '0',
          'window_fr': '0',
          'window_rl': '0',
          'window_rr': '0',
          'front_wiper': 'Off',
        });
        await put('/vehicle/hvac', {
          'power': 'false',
          'fan_speed': '2',
          'passenger_temp': '22',
        });
        for (final area in [
          'front_left',
          'front_right',
          'rear_left',
          'rear_right',
        ]) {
          await put('/vehicle/reading-lights', {
            'area': area,
            'value': 'false',
          });
        }
      }

      try {
        await resetFixture();
        // Deliberately leave a wrong lamp ON before starting the game.
        await put('/vehicle/reading-lights', {
          'area': 'front_left',
          'value': 'true',
        });
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: tutorialTheme(),
            home: TutorialScreen(controller: c, narrationPlayer: _Captions()),
          ),
        );
        await until(() => c.readyToStart, 'SDK ready');
        expect(c.vehicleCapabilities['lightControl'], true);
        expect(c.vehicleCapabilities['steering'], true);
        expect(c.vehicleCapabilities['doors'], contains('REAR'));
        await tester.ensureVisible(find.byKey(const Key('start-tutorial')));
        await tester.tap(find.byKey(const Key('start-tutorial')));
        await tester.pump();
        await dialogue();
        await until(() => !c.lightsResetting, 'Pre-existing lamp OFF reset');
        await assertActualLightsOff();
        final firstReset = c.lightResetRevision;
        await put('/vehicle/reading-lights', {
          'area': 'front_right',
          'value': 'true',
        });
        await until(
          () => c.lightResetRevision > firstReset && !c.lightsResetting,
          'Wrong sequence OFF reset',
        );
        await assertActualLightsOff();
        expect(c.powerCount, 0);
        await capture('carscape-vehicle-power');
        for (final area in [
          'rear_left',
          'rear_right',
          'front_left',
          'front_right',
        ]) {
          final count = c.powerCount;
          await put('/vehicle/reading-lights', {'area': area, 'value': 'true'});
          await until(() => c.powerCount == count + 1, 'Ordered lamp $area');
        }
        expect(c.stage, TutorialStage.glovebox);
        await dialogue();
        await put('/vehicle/hvac', {
          'power': 'true',
          'fan_speed': '2',
          'passenger_temp': '28',
        });
        await until(
          () => c.stage == TutorialStage.ventilation,
          'Passenger heat',
        );
        await dialogue();
        expect(find.text('지금 할 일'), findsNothing);
        expect(find.byKey(const Key('window-driver-down')), findsNothing);
        await capture('carscape-vehicle-gas');
        await put('/vehicle/body', {'window_fl': '100'});
        await until(
          () => c.coldCommentPlayed && c.frost > .4,
          'Too much window opening freezes display',
        );
        expect(c.stage, TutorialStage.ventilation);
        await capture('carscape-vehicle-freezing');
        await put('/vehicle/body', {
          'window_fl': '20',
          'window_fr': '20',
          'window_rl': '20',
          'window_rr': '20',
          'trunk': 'true',
        });
        await until(() => c.doors['REAR'] == true, 'Actual trunk sensor');
        await tester.pump(const Duration(seconds: 2));
        expect(c.stage, TutorialStage.ventilation);
        expect(c.coldLoss, greaterThanOrEqualTo(14));
        await put('/vehicle/body', {'trunk': 'false', 'door_fl': 'true'});
        await until(() => c.doors['ROW_1_LEFT'] == true, 'Actual door sensor');
        expect(c.stage, TutorialStage.ventilation);
        await put('/vehicle/body', {'door_fl': 'false'});
        await until(
          () => c.stage == TutorialStage.escape,
          'Four windows and warm recovery',
        );
        await dialogue();
        await capture('carscape-vehicle-frost');
        await put('/vehicle/controls', {'steering': '45'});
        await until(
          () => c.steeringAngle != null && c.steeringAngle! >= 30,
          'Early right steering',
        );
        expect(c.stage, TutorialStage.escape);
        await put('/vehicle/body', {'front_wiper': 'Low'});
        await until(() => c.shelterVisible, 'Actual wiper clears snow');
        expect(c.stage, TutorialStage.escape);
        await capture('carscape-vehicle-shelter');
        await put('/vehicle/controls', {'steering': '0'});
        await until(() => c.steeringAngle!.abs() <= 10, 'Centered steering');
        await put('/vehicle/controls', {'steering': '45'});
        await until(
          () => c.stage == TutorialStage.arrival,
          'Actual right turn',
        );
        await dialogue();
        expect(c.stage, TutorialStage.result);
        expect(c.result!.usedTestNavigation, false);
        await capture('carscape-vehicle-result');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await resetFixture();
        http.close(force: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
