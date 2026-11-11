import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/features/tutorial/domain/tutorial_script.dart';
import 'package:carscape/features/tutorial/integration/narration_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled Korean narration plays and can be interrupted', (
    _,
  ) async {
    final player = FrozenNightNarrationPlayer();
    addTearDown(player.dispose);

    for (final entry in TutorialScript.dialogue.entries) {
      for (final (index, _) in entry.value.indexed) {
        final clip = await rootBundle.load(
          'assets/frozen_night/voice/${entry.key.name}_${index + 1}.wav',
        );
        expect(clip.lengthInBytes, greaterThan(44));
      }
    }
    expect(
      (await rootBundle.load(
        'assets/frozen_night/voice/cold.wav',
      )).lengthInBytes,
      greaterThan(44),
    );

    final intro = TutorialScript.dialogue[TutorialStage.blackout]!.first.text;
    final elapsed = Stopwatch()..start();
    expect(await player.speak(intro), isTrue);
    expect(elapsed.elapsed, greaterThan(const Duration(seconds: 3)));

    final pending = player.speak(
      TutorialScript.dialogue[TutorialStage.glovebox]!.first.text,
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await player.stop();
    expect(await pending, isFalse);
    expect(await player.speak(TutorialScript.coldComment), isTrue);
  });
}
