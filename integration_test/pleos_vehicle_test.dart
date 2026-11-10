// Run only against the local Pleos AVD with its Virtual Console browser open.
// The HTTP writes below belong to the test fixture, never the application.
import 'dart:io';
import 'package:flutter/material.dart';
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
    'real Vehicle SDK observes console lights, heater, windows, wiper and all belt areas',
    (tester) async {
      final c = TutorialController();
      final http = HttpClient();
      Future<void> put(String path, Map<String, String> query) async {
        final request = await http.putUrl(
          Uri.http('127.0.0.1:8088', path, query),
        );
        final response = await request.close();
        final status = response.statusCode;
        await response.drain<void>();
        expect(
          status,
          200,
          reason:
              'Console fixture rejected $path; keep the PC console browser open.',
        );
      }

      Future<void> until(bool Function() condition, String description) async {
        final limit = DateTime.now().add(const Duration(seconds: 25));
        while (!condition()) {
          if (DateTime.now().isAfter(limit)) {
            fail(
              '$description; stage=${c.stage} problems=${c.vehicleIssues} capabilities=${c.vehicleCapabilities}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
      }

      Future<void> dialogue() async {
        while (c.dialogueActive) {
          await until(() => !c.paused, 'Narration is paused');
          await tester.pump();
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
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${Directory.systemTemp.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: tutorialTheme(),
          home: TutorialScreen(controller: c, narrationPlayer: _Captions()),
        ),
      );
      await until(() => c.readyToStart && c.liveVehicleMode, 'SDK connection');
      expect(c.vehicleCapabilities['heater'], isTrue);
      expect(c.beltSeats.map((seat) => seat.id), contains('ROW_2_CENTER'));
      for (final area in [
        'front_left',
        'front_right',
        'rear_left',
        'rear_right',
      ]) {
        await put('/vehicle/reading-lights', {'area': area, 'value': 'false'});
      }
      await put('/vehicle/hvac', {
        'power': 'false',
        'fan_speed': '2',
        'passenger_temp': '22',
      });
      await put('/vehicle/body', {
        'window_fl': '0',
        'window_fr': '0',
        'window_rl': '0',
        'window_rr': '0',
        'front_wiper': 'Off',
      });
      await tester.pump(const Duration(seconds: 2));
      await tester.ensureVisible(find.byKey(const Key('start-tutorial')));
      await tester.tap(find.byKey(const Key('start-tutorial')));
      await tester.pump();
      await dialogue();
      expect(find.text('지금 할 일'), findsNothing);
      expect(find.byKey(const Key('light-driver')), findsNothing);
      await capture('carscape-vehicle-power');

      const areas = ['rear_left', 'rear_right', 'front_right', 'front_left'];
      for (int i = 0; i < 4; i++) {
        await put('/vehicle/reading-lights', {
          'area': areas[i],
          'value': 'true',
        });
        await until(() => c.powerCount >= i + 1, 'Reading light ${areas[i]}');
      }
      await until(() => c.stage == TutorialStage.glovebox, 'Light sequence');
      await dialogue();
      expect(find.byKey(const Key('heater')), findsNothing);
      expect(c.gloveboxSensorAvailable, isFalse);
      await put('/vehicle/hvac', {
        'power': 'true',
        'fan_speed': '2',
        'passenger_temp': '28',
      });
      await until(
        () => c.stage == TutorialStage.windowRequest,
        'Warm passenger airflow',
      );
      await dialogue();
      await put('/vehicle/body', {'window_fl': '10'});
      await until(
        () => c.stage == TutorialStage.windowCircuit,
        'Window movement trigger',
      );
      await dialogue();
      for (final pair in const [
        ('window_rl', '20'),
        ('window_rr', '30'),
        ('window_fr', '10'),
        ('window_fl', '20'),
      ]) {
        await put('/vehicle/body', {pair.$1: pair.$2});
        await tester.pump(const Duration(milliseconds: 600));
      }
      await until(
        () => c.stage == TutorialStage.wipers,
        'Four real window positions',
      );
      await dialogue();
      await put('/vehicle/body', {'front_wiper': 'Low'});
      await until(
        () => c.stage == TutorialStage.departure,
        'Front wiper actual state',
      );
      await dialogue();
      await until(
        () => c.belts.values.every((value) => value != null),
        'All buckle sensors, including rear center',
      );
      expect(c.belts['ROW_2_CENTER'], isFalse);
      expect(c.allBelts, isFalse);
      expect(find.byKey(const Key('accelerator')), findsNothing);
      expect(find.byKey(const Key('belt-ROW_2_CENTER')), findsNothing);
      await capture('carscape-vehicle-belts');

      // This console version has no buckle input. Positive/all-buckled completion
      // is separately covered with normalized observations in unit tests.
      await put('/vehicle/body', {
        'front_wiper': 'Off',
        'window_fl': '0',
        'window_fr': '0',
        'window_rl': '0',
        'window_rr': '0',
      });
      await put('/vehicle/hvac', {
        'power': 'false',
        'fan_speed': '3',
        'passenger_temp': '22',
      });
      for (final area in areas) {
        await put('/vehicle/reading-lights', {'area': area, 'value': 'false'});
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      http.close(force: true);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
