/// Illustration drawn at the top of a theme card.
enum ThemeArt { frozenNight, downpour, parkingLot, missingDriver }

/// A playable escape theme shown on the home carousel.
class EscapeTheme {
  const EscapeTheme({
    required this.id,
    required this.title,
    required this.description,
    required this.chips,
    required this.art,
  });

  final String id;
  final String title;
  final String description;

  /// Short facts shown above the start button, e.g. play time and players.
  final List<String> chips;
  final ThemeArt art;
}

/// Story id of "얼어붙은 밤", also used as its record key.
const storyFrozenNight = 'story01';

/// Placeholder catalog taken from the design draft (design/png/06_Main.png).
/// Replace once the main scenarios are decided.
const escapeThemes = <EscapeTheme>[
  // First story: the former tutorial (features/tutorial, 문성훈).
  EscapeTheme(
    id: storyFrozenNight,
    title: '얼어붙은 밤',
    description: '눈보라 속에 멈춰 버린 차. 완전히 얼어붙기 전에 고치고 탈출해야 한다.',
    chips: ['약 15분', '2~4인', '실패 없음'],
    art: ThemeArt.frozenNight,
  ),
  EscapeTheme(
    id: 'case01',
    title: '시간당 120mm',
    description: '기록적인 폭우에 멈춰버린 차. 물이 차오르기 전에 단서를 풀어야 한다.',
    chips: ['약 30분', '2~4인', '난이도 ●●○'],
    art: ThemeArt.downpour,
  ),
  EscapeTheme(
    id: 'case02',
    title: '자정의 주차장',
    description: '라디오에서 흘러나오는 낯선 주파수.',
    chips: ['약 30분', '2~4인', '난이도 ●●○'],
    art: ThemeArt.parkingLot,
  ),
  EscapeTheme(
    id: 'case03',
    title: '사라진 운전기사',
    description: '단서가 가리키는 장소로 직접 달려가야 한다.',
    chips: ['약 2시간', '지역 코스'],
    art: ThemeArt.missingDriver,
  ),
];
