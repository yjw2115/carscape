import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished play of a story.
class PlayRecord {
  const PlayRecord({
    required this.storyId,
    required this.team,
    required this.date,
    required this.time,
    required this.hints,
  });

  final String storyId;
  final String team;
  final DateTime date;

  /// Ranked value: play time plus the hint penalty.
  final Duration time;
  final int hints;

  Map<String, Object> toJson() => {
    'story': storyId,
    'team': team,
    'date': date.toIso8601String(),
    'ms': time.inMilliseconds,
    'hints': hints,
  };

  factory PlayRecord.fromJson(Map<String, dynamic> j) => PlayRecord(
    storyId: j['story'] as String,
    team: j['team'] as String,
    date: DateTime.parse(j['date'] as String),
    time: Duration(milliseconds: j['ms'] as int),
    hints: j['hints'] as int,
  );
}

/// Each team's best record for [storyId], fastest first.
List<PlayRecord> ranking(Iterable<PlayRecord> records, String storyId) {
  final best = <String, PlayRecord>{};
  for (final r in records.where((r) => r.storyId == storyId)) {
    final b = best[r.team];
    if (b == null || r.time < b.time) best[r.team] = r;
  }
  return best.values.toList()..sort((a, b) {
    final byTime = a.time.compareTo(b.time);
    return byTime != 0 ? byTime : a.date.compareTo(b.date);
  });
}

/// Records on this device, kept across app restarts.
class RecordStore {
  RecordStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'records.v1';

  List<PlayRecord> get all => [
    for (final s in _prefs.getStringList(_key) ?? const <String>[])
      PlayRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> add(PlayRecord r) => _prefs.setStringList(_key, [
    ...?_prefs.getStringList(_key),
    jsonEncode(r.toJson()),
  ]);

  Future<void> clear() => _prefs.remove(_key);
}
