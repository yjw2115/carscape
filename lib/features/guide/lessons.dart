import 'package:flutter/material.dart';
import '../../vehicle/device_catalog.dart';

/// One very easy tutorial question: a situation solved by turning on one
/// real car function. Devices are never the ones "얼어붙은 밤" uses, so the
/// tutorial doesn't hint at the story.
class Lesson {
  const Lesson({
    required this.device,
    required this.icon,
    required this.title,
    required this.question,
    required this.hint,
    required this.explanation,
    this.speech,
  });

  /// Solved when this device turns on (value 1).
  final DeviceId device;
  final IconData icon;
  final String title;

  /// Shown on screen. Empty when the clue is only in [speech].
  final String question;

  /// Spoken by a passenger (with captions); the clue for listening lessons.
  final String? speech;
  final String hint;

  /// Shown after solving: what the function does in real driving.
  final String explanation;
}

const tutorialLessons = [
  // 1. Read the situation, press the named button.
  Lesson(
    device: DeviceId.recirculation,
    icon: Icons.autorenew_rounded,
    title: '터널에 들어가요',
    question: '곧 긴 터널이에요. 바깥 공기가 들어오지 않게 내·외기 순환 버튼을 눌러 내기로 바꿔 볼까요?',
    hint: '공조 버튼 줄에서 차 안에 화살표가 돌고 있는 모양의 버튼이에요.',
    explanation: '내기 모드는 바깥 공기를 막아요. 터널이나 매연이 심한 길에서 쓰면 좋아요.',
  ),
  // 2. The button isn't named: use the hint.
  Lesson(
    device: DeviceId.rearDefrost,
    icon: Icons.waves_rounded,
    title: '뒤가 안 보여요',
    question: '뒷유리에 김이 서려서 뒤가 잘 안 보여요. 어떻게 하면 좋을까요?\n모르겠으면 왼쪽의 힌트를 눌러 보세요.',
    hint: '뒷유리 열선을 켜요. 네모 안에 물결 모양이 있는 버튼이에요.',
    explanation: '뒷유리 열선은 유리를 데워 김과 성에를 없애요. 비 오는 날이나 추운 아침에 써요.',
  ),
  // 3. The clue is only in what a passenger says.
  Lesson(
    device: DeviceId.airCon,
    // Not the A/C snowflake: the answer must come from the line.
    icon: Icons.record_voice_over_outlined,
    title: '대사를 잘 들어요',
    question: '',
    speech: '차 안이 덥고 눅눅하네… 에어컨 좀 켜 줄래?',
    hint: '공조 버튼 줄의 A/C 버튼을 눌러 에어컨을 켜요.',
    explanation: '게임에서도 단서는 대사 속에 있어요. 놓쳤다면 "다시 듣기"로 언제든 다시 들을 수 있어요.',
  ),
];
