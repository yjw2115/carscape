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
      final hint = TextStyle(fontSize: 28 * s, color: p.description);
      final missing = session.devices.keys
          .where((id) => !session.canUse(id))
          .length;
      return ListView(
        children: [
          Text('차의 버튼으로 퍼즐을 푸는 법을 익혀요.', style: hint),
          SizedBox(height: 32 * s),
          RailCard(
            s: s,
            palette: p,
            child: Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 56 * s,
                  color: p.title,
                ),
                SizedBox(width: 24 * s),
                Expanded(
                  child: Text(
                    session.devices.isEmpty
                        ? '차량 점검 전이에요. 홈의 렌치 버튼으로 점검할 수 있어요.'
                        : missing == 0
                        ? '차량 점검 완료 · 모든 장치를 쓸 수 있어요'
                        : '차량 점검 완료 · $missing개 장치는 화면 터치로 대신해요',
                    style: TextStyle(fontSize: 30 * s, color: p.title),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24 * s),
          RailCard(
            s: s,
            palette: p,
            child: Text(
              progress.tutorialDone
                  ? '튜토리얼을 마쳤어요. 홈에서 첫 번째 스토리 "얼어붙은 밤"을 플레이할 수 있어요.'
                  : '튜토리얼 내용은 준비 중이에요. 지금은 "튜토리얼 마치기"를 누르면 '
                        '기본 훈련 배지를 받고 첫 번째 스토리가 열려요.',
              style: hint,
            ),
          ),
        ],
      );
    },
  );
}
