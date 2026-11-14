import 'tutorial_models.dart';

class TutorialScript {
  static const title = '얼어붙은 밤';
  static const coldComment = '추워서 손이 안 움직여...';
  static const Map<TutorialStage, List<DialogueLine>> dialogue = {
    TutorialStage.blackout: [DialogueLine('운전석', '다들 괜찮아? 어두워서 아무것도 안 보여...')],
    TutorialStage.glovebox: [
      DialogueLine(
        '운전석',
        '드디어 보이네. 다들 무사해서 다행이야. 그런데 차량이 고장났는지 움직이지가 않아.... 수리도구가 어디 있더라...?',
      ),
      DialogueLine('조수석', '글로브 박스에 있었을 거에요!'),
      DialogueLine('운전석', '다행이다... 어라 잠겨 있잖아!.... 아니 얼어있는 건가?'),
    ],
    TutorialStage.ventilation: [
      DialogueLine('운전석', '이거 고치려면 좀 걸릴 거 같네.... 뭐야! 가스가 새어나오잖아!'),
    ],
    TutorialStage.escape: [
      DialogueLine('운전석', '좀 춥긴 하지만 그래도 살 거 같네. 마침 수리도 끝났어. 어디로 가야 하지??'),
    ],
    TutorialStage.arrival: [
      DialogueLine('나레이션', '눈보라를 지나, 마침내 대피소에 도착했습니다.'),
      DialogueLine('운전석', '다들 수고했어. 따뜻한 데 오니까 살 것 같다.'),
    ],
  };
  static const Map<TutorialStage, List<String>> hints = {
    TutorialStage.power: [
      '설계도에서 트렁크의 배터리를 찾아보세요. 선은 어디로 이어지나요?',
      '뒷좌석 왼쪽에서 오른쪽으로, 그다음 앞좌석 왼쪽에서 오른쪽으로 이어져요.',
      '뒷좌석 왼쪽 → 뒷좌석 오른쪽 → 운전석 → 조수석 순서로 켜세요. 틀리면 네 등이 모두 꺼져요.',
    ],
    TutorialStage.glovebox: [
      '잠긴 게 아니라 얼어붙은 거라면, 무엇이 필요할까요?',
      '글로브박스는 조수석 앞에 있어요. 그쪽을 따뜻하게 만들어 보세요.',
      '공조 전원을 켜고 풍량을 1단계 이상, 조수석 온도를 26°C 이상으로 맞춰보세요.',
    ],
    TutorialStage.ventilation: [
      '가스를 줄이면서 온도도 초록 범위에 머물러야 해요.',
      '한 곳을 크게 여는 것보다 네 창문을 조금씩 열어 보세요. 차 문과 뒷 트렁크는 닫아 두세요.',
      '네 창문을 각각 20% 열고 차 문과 뒷 트렁크를 닫으세요. 두 게이지가 초록으로 안정되면 통과해요.',
    ],
    TutorialStage.escape: [
      '앞유리에 쌓인 눈부터 치워야 길을 찾을 수 있어요.',
      '와이퍼로 시야를 확보한 뒤, 대피소가 보이는 방향을 살펴보세요.',
      '앞유리 와이퍼를 켜세요. 대피소가 오른쪽에 나타나면 휠을 오른쪽으로 조금 돌리세요.',
    ],
  };
}
