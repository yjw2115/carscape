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
  @override
  Future<void> prepareStoryClimate() async {}

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

  testWidgets('intro home button goes back to the opener', (tester) async {
    final c = TutorialController(
      options: const TutorialOptions(enableClock: false),
    );
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1682, 1210);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: tutorialTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TutorialScreen(
                  controller: c,
                  previewOnly: true,
                  narrationPlayer: TestVoice(),
                ),
              ),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('intro-home')));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

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
      expect(find.text('와, 축하해요!'), findsOneWidget);
      expect(find.byKey(const Key('confetti')), findsOneWidget);
      for (final stat in ['플레이 시간', '힌트', '최종 기록']) {
        expect(find.text(stat), findsOneWidget);
      }
      expect(find.text('다시 체험하기'), findsNothing);
      expect(find.byKey(const Key('go-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'notes replay while time keeps running; cancelled hints are free, accepted hints count once',
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
      final dialog = tester.getCenter(find.byType(GlassDialog));
      expect(dialog.dx, closeTo(tester.view.physicalSize.width / 2, 2));
      expect(dialog.dy, closeTo(tester.view.physicalSize.height / 2, 2));
      expect(find.text('다들 괜찮아? 어두워서 아무것도 안 보여...'), findsOneWidget);
      expect(c.paused, isFalse);
      final before = c.elapsed;
      c.tick(const Duration(seconds: 2));
      expect(c.elapsed - before, const Duration(seconds: 2));
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
      expect(c.paused, isFalse);
      await tester.tap(find.text('이야기로 돌아가기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.paused, isFalse);
      expect(find.byKey(const Key('pause')), findsNothing);
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
      await tap(tester, 'dev-tools');
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
    expect(find.byType(GlassDialog), findsNothing);
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
      await tap(tester, 'dev-tools');
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

  testWidgets('start screen keeps only the title, concept and start', (
    tester,
  ) async {
    final c = TutorialController(
      options: const TutorialOptions(enableClock: false),
    );
    addTearDown(c.dispose);
    await setup(tester, c, size: const Size(1682, 1210));
    expect(find.text('얼어붙은 밤'), findsOneWidget);
    expect(find.textContaining('눈보라 속에 멈춰 버린 자동차'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('이야기에 귀 기울여요'), findsNothing);
    expect(find.text('글로브박스 열림 감지 지원'), findsNothing);
    final start = tester.getRect(find.byKey(const Key('start-tutorial')));
    expect(start.left, lessThan(1682 * .1));
    expect(start.bottom, greaterThan(1210 * .85));
    expect(start.height, greaterThanOrEqualTo(80));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next button sits bottom-left in Hyundai Sand', (tester) async {
    final c = TutorialController(
      options: const TutorialOptions(enableClock: false),
    );
    addTearDown(c.dispose);
    await setup(tester, c, size: const Size(1682, 1210));
    await tap(tester, 'start-tutorial');
    expect(find.text('다들 괜찮아? 어두워서 아무것도 안 보여...'), findsOneWidget);
    final next = find.byKey(const Key('next-dialogue'));
    final rect = tester.getRect(next);
    expect(rect.left, lessThan(1682 * .1));
    expect(rect.bottom, greaterThan(1210 * .85));
    final style = tester.widget<FilledButton>(next).style!;
    expect(style.backgroundColor!.resolve({}), const Color(0xFFE4DCD3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'in game: floating clock, no top or bottom bars, settings gear, give up',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      addTearDown(c.dispose);
      var exited = 0;
      tester.view.physicalSize = const Size(1682, 1210);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: tutorialTheme(),
          home: TutorialScreen(
            controller: c,
            previewOnly: true,
            narrationPlayer: TestVoice(),
            onExit: () => exited++,
          ),
        ),
      );
      await tap(tester, 'start-tutorial');
      await dialogue(tester, c);
      expect(c.stage, TutorialStage.power);
      final clock = tester.getRect(find.byKey(const Key('story-clock')));
      expect(clock.right, greaterThan(1682 * .9));
      expect(clock.top, lessThan(1210 * .1));
      expect(find.textContaining('OF 04'), findsNothing);
      expect(find.text('이전 단계'), findsNothing);
      expect(find.byKey(const Key('pause')), findsNothing);
      expect(find.byKey(const Key('story-bgm-settings')), findsNothing);

      await tap(tester, 'story-settings');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('나레이션 음성'), findsOneWidget);
      await tester.tap(find.byKey(const Key('story-voice')));
      await tester.pump();
      await tester.tap(find.text('닫기'));
      await tester.pump(const Duration(milliseconds: 250));

      final giveUp = tester.getRect(find.byKey(const Key('give-up')));
      expect(giveUp.right, greaterThan(1682 * .8));
      expect(giveUp.bottom, greaterThan(1210 * .85));
      await tap(tester, 'give-up');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(exited, 0);
      await tap(tester, 'give-up');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const Key('confirm-give-up')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(exited, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('defroster softens the snow in the last chapter', (
    tester,
  ) async {
    final c = TutorialController(
      options: const TutorialOptions(enableClock: false),
    );
    addTearDown(c.dispose);
    await setup(tester, c);
    for (int i = 0; i < 4; i++) {
      c.testNavigate(1);
    }
    await tester.pump();
    await dialogue(tester, c);
    expect(c.stage, TutorialStage.escape);
    expect(find.byKey(const Key('melting-snow')), findsNothing);
    await tap(tester, 'front-defroster');
    c.tick(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.melt, greaterThan(0));
    expect(c.visibility, 0);
    expect(find.byKey(const Key('melting-snow')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
