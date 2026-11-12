import 'package:shared_preferences/shared_preferences.dart';
import '../home/domain/escape_theme.dart';
import '../tutorial/domain/tutorial_models.dart';

/// Badge border grade (docs/handoff.md §7).
enum BadgeTier {
  basic('기본', '클리어'),
  silver('은색', '힌트 없이 클리어'),
  gold('금색', '힌트 없이, 제한 시간 절반 안에 클리어');

  const BadgeTier(this.label, this.rule);
  final String label;
  final String rule;
}

/// Badge id of the tutorial's "기본 훈련" badge. Story badges use story ids.
const tutorialBadgeId = 'tutorial';

/// Story time limits for the gold border. Stories without one top out at
/// silver.
const storyTimeLimits = {storyFrozenNight: Duration(minutes: 30)};

BadgeTier tierFor(TutorialResult r, Duration? limit) {
  if (r.hintsUsed > 0) return BadgeTier.basic;
  if (limit != null && r.playTime * 2 <= limit) return BadgeTier.gold;
  return BadgeTier.silver;
}

/// Unlocks and badges on this device, kept across app restarts.
/// Order: tutorial → "얼어붙은 밤" → every other story.
class Progress {
  Progress(this._prefs);
  final SharedPreferences _prefs;

  BadgeTier? badge(String id) {
    final i = _prefs.getInt('badge.$id');
    return i == null ? null : BadgeTier.values[i];
  }

  bool get tutorialDone => badge(tutorialBadgeId) != null;
  bool cleared(String storyId) => _prefs.getBool('cleared.$storyId') ?? false;

  /// Why [storyId] can't be played yet, or null when it can.
  String? lockedReason(String storyId) {
    if (!tutorialDone) return '튜토리얼을 마치면 열려요';
    if (storyId != storyFrozenNight && !cleared(storyFrozenNight)) {
      return '얼어붙은 밤을 마치면 열려요';
    }
    return null;
  }

  Future<void> markCleared(String storyId) =>
      _prefs.setBool('cleared.$storyId', true);

  /// Keeps the better of [tier] and the current badge. True when it changed.
  Future<bool> award(String id, BadgeTier tier) async {
    final current = badge(id);
    if (current != null && current.index >= tier.index) return false;
    await _prefs.setInt('badge.$id', tier.index);
    return true;
  }
}
