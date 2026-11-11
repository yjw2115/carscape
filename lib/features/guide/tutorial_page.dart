import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';

/// 튜토리얼 tab (윤종욱). Teaches how to play with the car's buttons.
/// The lessons come later; this is the shell they plug into.
///
/// Not to be confused with features/tutorial, which is the first story
/// "얼어붙은 밤" (문성훈).
class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key, required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) => RailPage(
    title: '튜토리얼',
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
            child: Text('튜토리얼 내용은 준비 중이에요.', style: hint),
          ),
        ],
      );
    },
  );
}
