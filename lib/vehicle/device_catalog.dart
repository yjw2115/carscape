/// Team-wide device IDs. Changing an ID or adding a device is a shared-rule
/// change: agree with the team first (CLAUDE.md).
///
/// - [usedInGame]: some scenario reads it. Never shown to players as such.
/// - [checkable]: may be picked for the hands-on check. Devices visible from
///   outside the car (창문, 와이퍼) and the accelerator are never asked for.
/// - [perSeat]: the SDK reports one value per seat.
enum DeviceId {
  // Read by the tutorial "얼어붙은 밤" (docs/tutorial-integration.md).
  cabinLight(
    '실내등',
    '실내등을 켜거나 꺼보세요',
    '천장 앞쪽, 실내등 스위치예요',
    usedInGame: true,
    perSeat: true,
  ),
  passengerHeater(
    '조수석 히터',
    '조수석 쪽 온도를 올려보세요',
    '공조 버튼 줄의 조수석 온도 조절이에요',
    usedInGame: true,
  ),
  glovebox('글로브박스', '글로브박스를 열었다 닫아보세요', '조수석 앞 수납함이에요', usedInGame: true),
  seatbelt(
    '안전벨트',
    '안전벨트를 풀었다 다시 채워보세요',
    '앉은 자리의 안전벨트면 돼요',
    usedInGame: true,
    perSeat: true,
  ),
  window('창문', '', '', usedInGame: true, perSeat: true, checkable: false),
  wiper('와이퍼', '', '', usedInGame: true, checkable: false),
  accelerator('가속 페달', '', '', usedInGame: true, checkable: false),
  gear('기어', '', '', usedInGame: true, checkable: false),

  // Decoys: common physical buttons, mixed in so the check spoils nothing.
  recirculation('내·외기 순환', '내·외기 순환 버튼을 눌러보세요', '공조 버튼 줄에 있는 차 안 화살표 모양 버튼이에요'),
  rearDefrost('뒷유리 열선', '뒷유리 열선 버튼을 눌러보세요', '공조 버튼 줄의 네모 안 물결 모양 버튼이에요'),
  steeringHeater('핸들 열선', '핸들 열선 버튼을 눌러보세요', '핸들 모양 아래 물결이 있는 버튼이에요'),
  airCon('A/C', 'A/C 버튼을 눌러보세요', '공조 버튼 줄의 A/C 글자 버튼이에요'),
  fanSpeed('바람 세기', '바람 세기를 바꿔보세요', '공조 버튼 줄의 팬 모양 버튼이에요');

  const DeviceId(
    this.label,
    this.prompt,
    this.where, {
    this.usedInGame = false,
    this.perSeat = false,
    this.checkable = true,
  });

  final String label;
  final String prompt;
  final String where;
  final bool usedInGame;
  final bool perSeat;
  final bool checkable;
}

enum Seat { driver, passenger, rearLeft, rearRight }

/// Gear value meaning "P". Everything else (or no reading) is not parked.
const gearPark = 1;
