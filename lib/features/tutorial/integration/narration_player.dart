import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../domain/tutorial_script.dart';

abstract interface class NarrationPlayer {
  Future<bool> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Frozen Night's dialogue plays from bundled Korean clips on each platform.
class FrozenNightNarrationPlayer implements NarrationPlayer {
  static final _clips = <String, String>{
    for (final entry in TutorialScript.dialogue.entries)
      for (final (index, line) in entry.value.indexed)
        line.text: '${entry.key.name}_${index + 1}.wav',
    TutorialScript.coldComment: 'cold.wav',
  };

  AudioPlayer? _player;
  Future<void> _commands = Future.value();
  StreamSubscription<void>? _completionSubscription;
  Completer<bool>? _playing;
  int _revision = 0;
  bool _disposed = false;

  Future<void> _queue(Future<void> Function() action) {
    final next = _commands.then((_) => action());
    _commands = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<bool> speak(String text) async {
    final clip = _clips[text];
    if (_disposed || clip == null) return false;

    final request = ++_revision;
    final completion = Completer<bool>();
    try {
      await _queue(() async {
        await _stopCurrent();
        if (request != _revision) {
          completion.complete(false);
          return;
        }
        final player = _player ??= AudioPlayer();
        _playing = completion;
        _completionSubscription = player.onPlayerComplete.listen(
          (_) {
            if (!completion.isCompleted) completion.complete(true);
          },
          onError: (Object _) {
            if (!completion.isCompleted) completion.complete(false);
          },
        );
        await player.play(AssetSource('frozen_night/voice/$clip'));
      });
      return await completion.future.timeout(const Duration(seconds: 25));
    } catch (_) {
      // A delayed failure must never interrupt a newer line.
      if (request == _revision) await stop();
      return false;
    }
  }

  Future<void> _stopCurrent() async {
    await _completionSubscription?.cancel();
    _completionSubscription = null;
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete(false);
    await _player?.stop();
  }

  @override
  Future<void> stop() async {
    ++_revision;
    try {
      await _queue(_stopCurrent);
    } catch (_) {
      // The screen can continue showing captions when the audio device fails.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    try {
      await _player?.dispose();
    } finally {
      _player = null;
    }
  }
}
