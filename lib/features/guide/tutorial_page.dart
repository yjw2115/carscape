import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';
import '../badges/badge_pages.dart';
import '../badges/progress.dart';

/// 튜토리얼 tab (윤종욱). Teaches how to play with the car's buttons.
/// The lessons come later; this is the shell they plug into.
///
/// Not to be confused with features/tutorial, which is the first story
/// "얼어붙은 밤" (문성훈).
class TutorialPage extends StatelessWidget {
  const TutorialPage({
    super.key,
    required this.session,
    required this.progress,
  });
  final GameSession session;
  final Progress progress;

  // ponytail: one button stands in for the lessons until they exist; the
  // last lesson calls the same thing.
  Future<void> _finish(BuildContext context) async {
    await progress.award(tutorialBadgeId, BadgeTier.basic);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const BadgeGetPage(
          id: tutorialBadgeId,
          name: '기본 훈련',
          tier: BadgeTier.basic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RailPage(
    title: '튜토리얼',
    rail: (s, p) => [
      RailAction(
        key: const Key('finishTutorial'),
        s: s,
        palette: p,
        primary: !progress.tutorialDone,
        icon: Icons.flag_outlined,
        // Korean wraps per character; break between the words ourselves.
        label: progress.tutorialDone ? '완료했어요' : '튜토리얼\n마치기',
        onTap: progress.tutorialDone ? null : () => _finish(context),
      ),
    ],
    body: (s, p) {
      final missing = session.devices.keys
          .where((id) => !session.canUse(id))
          .length;
      final checked = session.devices.isNotEmpty;
      final done = progress.tutorialDone;
      final title = TextStyle(
        fontSize: 34 * s,
        fontWeight: FontWeight.w600,
        color: p.title,
      );
      return ListView(
        children: [
          RailCard(
            s: s,
            palette: p,
            child: Row(
              children: [
                Icon(Icons.build_outlined, size: 52 * s, color: p.title),
                SizedBox(width: 24 * s),
                Expanded(child: Text('기능점검', style: title)),
                StatusChip(
                  s: s,
                  palette: p,
                  label: !checked
                      ? '점검 전'
                      : missing == 0
                      ? '완료'
                      : '화면 터치 $missing개',
                  tone: !checked
                      ? ChipTone.neutral
                      : missing == 0
                      ? ChipTone.ok
                      : ChipTone.warning,
                ),
              ],
            ),
          ),
          SizedBox(height: 24 * s),
          RailCard(
            s: s,
            palette: p,
            child: Row(
              children: [
                BadgeMedal(
                  id: tutorialBadgeId,
                  tier: done ? BadgeTier.basic : null,
                  size: 120 * s,
                  palette: p,
                ),
                SizedBox(width: 32 * s),
                Expanded(child: Text('기본 훈련 배지', style: title)),
                StatusChip(
                  s: s,
                  palette: p,
                  icon: done
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  label: done ? '얼어붙은 밤 열림' : '얼어붙은 밤 잠김',
                  tone: done ? ChipTone.ok : ChipTone.neutral,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
