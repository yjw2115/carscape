import 'package:flutter/material.dart';
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
    'player can complete all five puzzles using only visible controls',
    (tester) async {
      final c = TutorialController(
        options: const TutorialOptions(enableClock: false),
      );
      addTearDown(c.dispose);
      await setup(tester, c);
      await tap(tester, 'start-tutorial');
      await dialogue(tester, c);
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
      await tap(tester, 'window-driver-up');
      await dialogue(tester, c);
      const moves = [2, 3, 1, 2];
      for (final seat in CarSeat.values) {
        for (int i = 0; i < moves[seat.index]; i++) {
          await tap(tester, 'window-${seat.name}-down');
        }
      }
      await dialogue(tester, c);
      await tap(tester, 'wiper');
      await dialogue(tester, c);
      await tap(tester, 'accelerator');
      expect(c.stage, TutorialStage.departure);
      for (final seat in CarSeat.values) {
        await tap(tester, 'belt-${seat.name}');
      }
      await tap(tester, 'accelerator');
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
      await tester.tap(find.text('이야기로 돌아가기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.paused, isFalse);
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
      await tap(tester, 'window-driver-down');
      await dialogue(tester, c);
      expect(tester.takeException(), isNull);
      const moves = [2, 3, 1, 2];
      for (final seat in CarSeat.values) {
        for (int i = 0; i < moves[seat.index]; i++) {
          await tap(tester, 'window-${seat.name}-down');
        }
      }
      await dialogue(tester, c);
      await tap(tester, 'wiper');
      await dialogue(tester, c);
      for (final seat in CarSeat.values) {
        await tap(tester, 'belt-${seat.name}');
      }
      await tap(tester, 'accelerator');
      await dialogue(tester, c);
      expect(c.stage, TutorialStage.result);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
