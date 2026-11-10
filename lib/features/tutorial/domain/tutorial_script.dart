import 'tutorial_models.dart';

class TutorialScript {
  static const title = '얼어붙은 밤';

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
    TutorialStage.windowRequest: [
      DialogueLine(
        '운전석',
        '이거 고치려면 좀 걸릴 거 같네.... 근데 공기가 좀 희박한 거 같지 않아? 좀 어지럽네.... 창문을 조금만 열어줘',
      ),
    ],
    TutorialStage.windowCircuit: [DialogueLine('운전석', '창문도 먹통이구먼')],
    TutorialStage.wipers: [
      DialogueLine('운전석', '좀 춥긴 하지만 그래도 살 거 같네. 마침 수리도 끝났어. 어디로 가야 하지??'),
      DialogueLine('조수석', '대피소가 근처긴 할 텐데요... 눈이 쌓여서 아무것도 안 보이네요.'),
    ],
    TutorialStage.departure: [
      DialogueLine('운전석', '저기 대피소가 보인다! 길이 험난하니까 다들 조심해! 모두 살아남는 거야!'),
    ],
    TutorialStage.arrival: [
      DialogueLine('나레이션', '눈보라를 지나, 마침내 대피소에 도착했습니다.'),
      DialogueLine('운전석', '다들 수고했어. 따뜻한 데 오니까 살 것 같다.'),
    ],
  };

  static const Map<TutorialStage, List<String>> hints = {
    TutorialStage.power: [
      '설계도에서 트렁크의 배터리를 찾아보세요. 선은 어디로 이어지나요?',
      '차의 뒤쪽에서 시작해 앞쪽으로 가요. 뒷좌석 왼쪽 다음은 오른쪽이에요.',
      '실내등을 뒷좌석 왼쪽 → 뒷좌석 오른쪽 → 조수석 → 운전석 순서로 켜세요. 틀렸다면 처음부터 다시!',
    ],
    TutorialStage.glovebox: [
      '잠긴 게 아니라 얼어붙은 거라면, 무엇이 필요할까요?',
      '글로브박스는 조수석 앞에 있어요. 그쪽을 따뜻하게 만들어 보세요.',
      '조수석 히터를 켠 다음 글로브박스를 여세요. 감지 기능이 없는 차는 히터만 켜도 돼요.',
    ],
    TutorialStage.windowRequest: [
      '방금 들은 대사에 다음 행동이 담겨 있어요.',
      '바깥 공기가 필요해요. 어느 자리든 괜찮아요.',
      '아무 좌석의 창문 올림 또는 내림 버튼을 한 번 누르세요.',
    ],
    TutorialStage.windowCircuit: [
      '네 자리의 창문 버튼이 각각 같은 색의 회로를 위아래로 움직여요.',
      '왼쪽 전원에서 오른쪽 출구까지 선이 끊기지 않게 이으세요. 파란 화살표가 길이에요.',
      '뒷좌석 왼쪽 2칸, 뒷좌석 오른쪽 3칸, 조수석 1칸, 운전석 2칸 내리세요. 처음 위치에서의 이동량이에요. 「처음 위치」로 돌아갈 수 있어요.',
    ],
    TutorialStage.wipers: [
      '대피소가 없어진 건 아니에요. 앞을 가리는 걸 치워보세요.',
      '앞유리에 눈이 쌓였어요. 유리를 쓸어 주는 장치를 찾아보세요.',
      '와이퍼를 켜세요. 한 번 작동하면 대피소가 보여요.',
    ],
    TutorialStage.departure: [
      '출발하기 전에 네 사람 모두 준비됐는지 확인해 보세요.',
      '각 좌석의 안전벨트가 모두 연결되어야 출발할 수 있어요.',
      '네 좌석 안전벨트를 모두 연결한 뒤 화면의 「악셀 밟기」를 누르세요. 실제 차량을 움직이는 기능은 없어요.',
    ],
  };
}
