import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carscape/features/tutorial/integration/tutorial_input_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carscape/features/tutorial/domain/tutorial_controller.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/integration/narration_player.dart';
import 'package:carscape/features/tutorial/presentation/tutorial_screen.dart';
import 'package:carscape/features/tutorial/presentation/tutorial_style.dart';

class TestVoice implements NarrationPlayer {
  final spoken = <String>[];
  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class PendingLightSource implements TutorialInputSource {
  final stream = StreamController<TutorialVehicleInput>.broadcast();
  final scopes = <bool>[];
  Completer<void>? reset;
  @override
  Stream<TutorialVehicleInput> get events => stream.stream;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> setLightPuzzleActive(bool active) async {
    scopes.add(active);
    if (!active && reset != null && !reset!.isCompleted) {
      reset!.completeError(StateError('cancelled'));
    }
  }

  @override
  Future<void> resetReadingLights() {
    reset = Completer<void>();
    return reset!.future;
  }
}

void main() {
  Future<void> setup(
    WidgetTester tester,
    TutorialController c, {
    Size size = const Size(960, 600),
    TestVoice? voice,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: tutorialTheme(),
        home: TutorialScreen(
          controller: c,
          previewOnly: true,
          narrationPlayer: voice ?? TestVoice(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> dialogue(WidgetTester tester, TutorialController c) async {
    while (c.dialogueActive) {
      await tap(tester, 'next-dialogue');
    }
  }

  testWidgets(
    'player can complete all four chapters using only visible controls',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      addTearDown(c.dispose);
      await setup(tester, c);
      await tap(tester, 'start-tutorial');
      await dialogue(tester, c);
      expect(find.text('지금 할 일'), findsNothing);
      await tap(tester, 'light-driver');
      expect(c.powerCount, 0);
      for (final seat in CarSeat.values) {
        await tap(tester, 'light-${seat.name}');
      }
      await dialogue(tester, c);
      await tap(tester, 'glovebox');
      expect(c.stage, TutorialStage.glovebox);
      await tap(tester, 'heater');
      await tap(tester, 'glovebox');
      await dialogue(tester, c);
      for (final seat in CarSeat.values) {
        await tap(tester, 'window-${seat.name}-down');
      }
      for (int i = 0; i < 60; i++) {
        c.tick(const Duration(milliseconds: 100));
      }
      await tester.pump();
      await dialogue(tester, c);
      await tap(tester, 'wiper');
      c.tick(const Duration(seconds: 3));
      await tester.pump();
      await tap(tester, 'steering-45');
      await dialogue(tester, c);
      expect(find.text('우리 모두, 살아남았다.'), findsOneWidget);
      expect(find.text('사용한 힌트'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'notes replay and pause; cancelled hints are free, accepted hints count once',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      final voice = TestVoice();
      addTearDown(c.dispose);
      await setup(tester, c, voice: voice);
      await tap(tester, 'start-tutorial');
      await dialogue(tester, c);
      await tap(tester, 'notes');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('다들 괜찮아? 어두워서 아무것도 안 보여...'), findsOneWidget);
      expect(c.paused, isTrue);
      expect(voice.spoken.length, greaterThanOrEqualTo(2));
      expect(c.hintsUsed, 0);
      await tap(tester, 'hint');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('돌아가기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.hintsUsed, 0);
      await tap(tester, 'hint');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('힌트 열기 · +1분'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.hintsUsed, 1);
      await tester.tap(find.text('해볼게요'));
      await tester.pump(const Duration(milliseconds: 250));
      await tap(tester, 'hint');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('힌트를 열면'), findsNothing);
      expect(find.text('힌트 열기 · +1분'), findsNothing);
      expect(c.hintsUsed, 2);
      await tester.tap(find.text('해볼게요'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.paused, isTrue);
      await tester.tap(find.text('이야기로 돌아가기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.paused, isFalse);
      await tap(tester, 'pause');
      expect(c.paused, isTrue);
      await tap(tester, 'resume');
      expect(c.paused, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(640, 600),
    const Size(400, 800),
    const Size(1200, 720),
    // The car's app area, where the story screen zooms in.
    const Size(1682, 1210),
  ]) {
    testWidgets('every chapter lays out at ${size.width} x ${size.height}', (
      tester,
    ) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      addTearDown(c.dispose);
      await setup(tester, c, size: size);
      expect(tester.takeException(), isNull);
      await tap(tester, 'start-tutorial');
      await dialogue(tester, c);
      for (final seat in CarSeat.values) {
        await tap(tester, 'light-${seat.name}');
      }
      await dialogue(tester, c);
      expect(tester.takeException(), isNull);
      await tap(tester, 'heater');
      await tap(tester, 'glovebox');
      await dialogue(tester, c);
      for (final seat in CarSeat.values) {
        await tap(tester, 'window-${seat.name}-down');
      }
      for (int i = 0; i < 60; i++) {
        c.tick(const Duration(milliseconds: 100));
      }
      await tester.pump();
      await dialogue(tester, c);
      expect(tester.takeException(), isNull);
      await tap(tester, 'wiper');
      c.tick(const Duration(seconds: 3));
      await tester.pump();
      await tap(tester, 'steering-45');
      await dialogue(tester, c);
      expect(c.stage, TutorialStage.result);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'temporary navigation stays usable during dialogue and first resets to intro',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      addTearDown(c.dispose);
      await setup(tester, c);
      await tap(tester, 'test-next');
      expect(c.stage, TutorialStage.power);
      await tap(tester, 'test-next');
      expect(c.dialogueActive, isTrue);
      await tap(tester, 'test-next');
      expect(c.stage, TutorialStage.ventilation);
      await tap(tester, 'test-previous');
      expect(c.stage, TutorialStage.glovebox);
      await tap(tester, 'test-first');
      expect(find.byKey(const Key('start-tutorial')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cold reaction plays once without a dialog or input pause', (
    tester,
  ) async {
    final c = TutorialController(
      options: const TutorialOptions(enableClock: false),
    );
    final voice = TestVoice();
    addTearDown(c.dispose);
    await setup(tester, c, voice: voice);
    for (int i = 0; i < 3; i++) {
      c.testNavigate(1);
    }
    await tester.pump();
    await dialogue(tester, c);
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        100,
        seat: CarSeat.driver,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('cold-caption')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(c.acceptsInput, isTrue);
    expect(voice.spoken.where((text) => text == '추워서 손이 안 움직여...').length, 1);
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        0,
        seat: CarSeat.driver,
      ),
    );
    c.receive(
      const TutorialVehicleInput(
        VehicleInputKind.window,
        100,
        seat: CarSeat.driver,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(voice.spoken.where((text) => text == '추워서 손이 안 움직여...').length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'leaving the light chapter cancels a pending physical reset immediately',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      final source = PendingLightSource();
      addTearDown(c.dispose);
      addTearDown(source.stream.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: tutorialTheme(),
          home: TutorialScreen(
            controller: c,
            inputSource: source,
            narrationPlayer: TestVoice(),
          ),
        ),
      );
      c.receive(
        const TutorialVehicleInput(VehicleInputKind.configuration, 0, data: {}),
      );
      c.receive(const TutorialVehicleInput(VehicleInputKind.connection, 1));
      c.receive(const TutorialVehicleInput(VehicleInputKind.parking, 1));
      await tester.pump();
      await tap(tester, 'test-next');
      await tester.pump();
      expect(c.stage, TutorialStage.power);
      expect(source.reset, isNotNull);
      expect(source.reset!.isCompleted, isFalse);
      await tap(tester, 'test-next');
      await tester.pump();
      expect(c.stage, TutorialStage.glovebox);
      expect(source.scopes.last, isFalse);
      expect(source.reset!.isCompleted, isTrue);
      expect(c.vehicleIssues.containsKey('lightReset'), isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
