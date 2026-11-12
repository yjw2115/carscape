import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences, kept across app restarts.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);
  final SharedPreferences _prefs;

  /// 0–1. Applied to the narration voice.
  double get narrationVolume => _prefs.getDouble('narrationVolume') ?? 1;
  bool get bgmOn => _prefs.getBool('bgmOn') ?? true;

  /// 0–1. Shared by the home and story music players.
  double get bgmVolume => _prefs.getDouble('bgmVolume') ?? 0.6;

  set narrationVolume(double v) =>
      _save(_prefs.setDouble('narrationVolume', v));
  set bgmOn(bool v) => _save(_prefs.setBool('bgmOn', v));
  set bgmVolume(double v) => _save(_prefs.setDouble('bgmVolume', v));

  void _save(Future<bool> write) {
    notifyListeners();
    write.ignore();
  }
}
