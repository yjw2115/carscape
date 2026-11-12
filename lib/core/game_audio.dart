import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../features/settings/app_settings.dart';

enum GameMusic {
  home('audio/carscape-home-bgm.wav'),
  frozenNight('audio/carscape-frozen-night-bgm.wav');

  const GameMusic(this.asset);
  final String asset;
}

AudioContext _mixWithGameAudio() => AudioContext(
  android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
);

/// Owns music for the whole app so settings and story routes share one player.
class GameAudio {
  GameAudio(this.settings) {
    settings.addListener(refreshMusic);
  }

  final AppSettings settings;
  AudioPlayer? _musicPlayer;
  GameMusic _requestedMusic = GameMusic.home;
  GameMusic? _playingMusic;
  bool _active = true;
  bool _disposed = false;
  Future<void> _musicCommands = Future.value();
  _ChapterCue? _cue;

  void setMusic(GameMusic music) {
    if (_requestedMusic == music) return;
    _requestedMusic = music;
    refreshMusic();
  }

  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    refreshMusic();
  }

  void refreshMusic() {
    if (_disposed) return;
    _musicCommands = _musicCommands.then((_) => _applyMusic()).catchError((
      Object _,
    ) {
      // Autoplay can be retried from a browser user gesture.
      _playingMusic = null;
    });
  }

  Future<void> _applyMusic() async {
    if (_disposed) return;
    if (!_active || !settings.bgmOn) {
      await _musicPlayer?.stop();
      _playingMusic = null;
      return;
    }
    final player = _musicPlayer ??= (AudioPlayer()..positionUpdater = null);
    final track = _requestedMusic;
    if (_playingMusic == track) {
      await player.setVolume(settings.bgmVolume);
      return;
    }
    await player.stop();
    await player.setAudioContext(_mixWithGameAudio());
    // The PCM files end with five seconds of silence.
    await player.setReleaseMode(ReleaseMode.loop);
    if (_disposed || !_active || track != _requestedMusic || !settings.bgmOn) {
      _playingMusic = null;
      return;
    }
    await player.play(AssetSource(track.asset), volume: settings.bgmVolume);
    _playingMusic = track;
  }

  Future<void> playChapterClear() async {
    if (_disposed) return;
    stopChapterClear();
    final cue = _cue = _ChapterCue();
    try {
      await cue.play();
    } finally {
      if (identical(_cue, cue)) _cue = null;
    }
  }

  void stopChapterClear() {
    final cue = _cue;
    _cue = null;
    cue?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    settings.removeListener(refreshMusic);
    stopChapterClear();
    await _musicCommands;
    try {
      await _musicPlayer?.dispose();
    } catch (_) {
      // The audio plugin may be absent in test and preview environments.
    }
  }
}

class _ChapterCue {
  final _player = AudioPlayer()..positionUpdater = null;
  final _finished = Completer<void>();

  void cancel() {
    if (!_finished.isCompleted) _finished.complete();
  }

  Future<void> play() async {
    final completion = _player.onPlayerComplete.listen(
      (_) => cancel(),
      onError: (Object _, StackTrace _) => cancel(),
    );
    try {
      await _player.setAudioContext(_mixWithGameAudio());
      if (_finished.isCompleted) return;
      await _player
          .play(AssetSource('audio/carscape-chapter-clear.wav'), volume: .8)
          .timeout(const Duration(seconds: 4));
      await _finished.future.timeout(const Duration(seconds: 4));
    } catch (_) {
      // A missing output device must not prevent chapter advancement.
    } finally {
      await completion.cancel();
      try {
        await _player.dispose();
      } catch (_) {
        // The player may have failed before it opened the audio device.
      }
    }
  }
}
