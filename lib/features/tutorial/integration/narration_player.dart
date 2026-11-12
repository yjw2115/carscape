import 'package:flutter_tts/flutter_tts.dart';

abstract interface class NarrationPlayer {
  Future<bool> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Uses the OS/browser Korean voice during the playable preview. This is not
/// the Pleos TTS SDK. A recorded-voice player can replace this interface later.
class SystemNarrationPlayer implements NarrationPlayer {
  SystemNarrationPlayer({this.volume = 1});

  /// 0–1, from the player's settings.
  final double volume;
  final FlutterTts _tts = FlutterTts();
  Future<bool>? _initialization;

  Future<bool> _initialize() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(0.95);
      await _tts.setVolume(volume);
      final available = await _tts.isLanguageAvailable('ko-KR');
      return available == true || available == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> speak(String text) async {
    try {
      if (!await (_initialization ??= _initialize())) return false;
      final result = await _tts
          .speak(text)
          .timeout(const Duration(seconds: 40));
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      /* Captions remain available. */
    }
  }

  @override
  Future<void> dispose() => stop();
}
