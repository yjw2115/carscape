/// A playable escape theme shown on the home carousel.
class EscapeTheme {
  const EscapeTheme({
    required this.id,
    required this.title,
    required this.description,
    this.chips = const [],
    this.photo,
  });

  final String id;
  final String title;
  final String description;

  /// Short facts shown above the start button, e.g. play time and players.
  final List<String> chips;

  /// Image asset for the card top. Null only for [comingSoonTheme].
  final String? photo;

  /// Teaser card with no story behind it yet.
  bool get comingSoon => photo == null;
}

/// Story id of "얼어붙은 밤", also used as its record key.
const storyFrozenNight = 'story01';

/// Playable stories, in carousel order. Records and badges list these.
const escapeThemes = <EscapeTheme>[
  // First story: the former tutorial (features/tutorial, 문성훈).
  EscapeTheme(
    id: storyFrozenNight,
    title: '얼어붙은 밤',
    description: '눈보라 속에 멈춰 버린 차. 완전히 얼어붙기 전에 고치고 탈출해야 한다.',
    chips: ['약 15분', '2~4인', '실패 없음'],
    // Same image as the story's opening screen (frozenNightCabin).
    photo: 'assets/frozen_night/art/cabin.jpg',
  ),
  EscapeTheme(
    id: 'case01',
    title: '자정의 주차장',
    description: '자정의 지하주차장. 저절로 켜진 라디오가 사라진 사람의 마지막 흔적을 들려줘요.',
    chips: ['약 30분', '2~4인', '난이도 ●●○'],
    photo: 'assets/themes/midnight_parking.webp',
  ),
  EscapeTheme(
    id: 'case02',
    title: '멈춘 시계탑',
    description: '시계탑이 멈춘 순간, 이 차는 타임머신이 되었어요. 과거와 미래를 오가며 시간을 되돌리세요.',
    chips: ['약 30분', '2~4인', '난이도 ●●●'],
    photo: 'assets/themes/clock_tower.jpg',
  ),
];

/// Last card on the home carousel, hinting at stories still to come.
const comingSoonTheme = EscapeTheme(
  id: 'comingSoon',
  title: '출시 예정',
  description: '새로운 사건이 준비되고 있어요. 다음 탈출을 기대해 주세요.',
  chips: ['새 스토리', 'COMING SOON'],
);

/// Home carousel: every story, then the coming-soon teaser at the right end.
const homeThemes = [...escapeThemes, comingSoonTheme];
