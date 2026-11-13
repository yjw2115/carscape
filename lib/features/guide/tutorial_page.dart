import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';
import '../../vehicle/vehicle_service.dart';
import '../badges/badge_pages.dart';
import '../entry/check_intro_screen.dart' show fakeVehicleCorner;
import '../badges/progress.dart';
import '../home/presentation/home_palette.dart';
import 'lesson_controller.dart';

/// Reads a passenger line aloud. Captions are always on screen, so a missing
/// voice never blocks the tutorial.
typedef Speak = Future<void> Function(String text);

Speak systemSpeaker({double volume = 1}) {
  final tts = FlutterTts();
  return (text) async {
    try {
      await tts.setLanguage('ko-KR');
      await tts.setVolume(volume);
      await tts.speak(text);
    } catch (_) {
      /* Captions remain. */
    }
  };
}

/// 튜토리얼 tab (윤종욱): three very easy questions solved with real car
/// buttons. Finishing gives the 기본 훈련 badge and opens "얼어붙은 밤".
///
/// Not to be confused with features/tutorial, which is the first story
/// "얼어붙은 밤" (문성훈).
class TutorialPage extends StatefulWidget {
  const TutorialPage({
    super.key,
    required this.vehicle,
    required this.session,
    required this.progress,
    required this.speak,
  });

  final VehicleService vehicle;
  final GameSession session;
  final Progress progress;
  final Speak speak;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  late final c = LessonController(widget.vehicle, widget.session);

  @override
  void initState() {
    super.initState();
    _say();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _say() {
    final line = c.lesson.speech;
    if (line != null) widget.speak(line);
  }

  Future<void> _next() async {
    if (c.next()) return _say();
    final earned = await widget.progress.award(
      tutorialBadgeId,
      BadgeTier.basic,
    );
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (!earned) return navigator.pop();
    await navigator.pushReplacement(
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final l = c.lesson;
      return RailPage(
        title: '튜토리얼 · ${c.index + 1} / ${c.lessons.length}',
        overlay: (s, _) => fakeVehicleCorner(widget.vehicle, s),
        rail: (s, p) => [
          if (c.solved)
            RailAction(
              key: const Key('lessonNext'),
              s: s,
              palette: p,
              primary: true,
              icon: c.isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
              label: c.isLast ? '마치기' : '다음',
              onTap: _next,
            )
          else ...[
            RailAction(
              key: const Key('lessonHint'),
              s: s,
              palette: p,
              icon: Icons.lightbulb_outline_rounded,
              label: '힌트',
              onTap: c.hintShown ? null : c.showHint,
            ),
            if (l.speech != null)
              RailAction(
                key: const Key('lessonReplay'),
                s: s,
                palette: p,
                icon: Icons.replay_rounded,
                label: '다시 듣기',
                onTap: _say,
              ),
            if (c.byTouch)
              RailAction(
                key: const Key('lessonTouch'),
                s: s,
                palette: p,
                primary: true,
                icon: Icons.touch_app_outlined,
                label: '화면에서\n켜기',
                onTap: c.solveByTouch,
              ),
          ],
        ],
        body: (s, p) {
          final text = TextStyle(fontSize: 30 * s, color: p.description);
          return ListView(
            children: [
              RailCard(
                key: ValueKey(c.index),
                s: s,
                palette: p,
                highlight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(l.icon, size: 64 * s, color: p.title),
                        SizedBox(width: 20 * s),
                        Text(
                          l.title,
                          style: TextStyle(
                            fontSize: 40 * s,
                            fontWeight: FontWeight.w600,
                            color: p.title,
                          ),
                        ),
                      ],
                    ),
                    if (l.question.isNotEmpty) ...[
                      SizedBox(height: 24 * s),
                      Text(
                        keepWords(l.question),
                        style: TextStyle(
                          fontSize: 38 * s,
                          height: 1.4,
                          color: p.title,
                        ),
                      ),
                    ],
                    if (l.speech != null) ...[
                      SizedBox(height: 24 * s),
                      _SpeechBubble(s: s, palette: p, text: l.speech!),
                    ],
                    if (c.hintShown) ...[
                      SizedBox(height: 24 * s),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_rounded,
                            size: 36 * s,
                            color: HyundaiColors.sand,
                          ),
                          SizedBox(width: 12 * s),
                          Expanded(child: Text(keepWords(l.hint), style: text)),
                        ],
                      ),
                    ],
                    SizedBox(height: 32 * s),
                    _Status(s: s, palette: p, c: c),
                  ],
                ),
              ),
              if (c.solved && l.explanation != null) ...[
                SizedBox(height: 24 * s),
                RailCard(
                  s: s,
                  palette: p,
                  child: Text(keepWords(l.explanation!), style: text),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.s,
    required this.palette,
    required this.text,
  });

  final double s;
  final HomePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 32 * s,
        backgroundColor: palette.chip,
        child: Icon(Icons.person_rounded, size: 40 * s, color: palette.onChip),
      ),
      SizedBox(width: 18 * s),
      Flexible(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 20 * s),
          decoration: BoxDecoration(
            color: palette.chip,
            borderRadius: BorderRadius.circular(24 * s),
          ),
          child: Text(
            keepWords('“$text”'),
            style: TextStyle(fontSize: 34 * s, color: palette.onChip),
          ),
        ),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.s, required this.palette, required this.c});
  final double s;
  final HomePalette palette;
  final LessonController c;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final (text, color, icon) = c.solved
        ? ('정답이에요!', HyundaiColors.activeBlue, Icons.check_circle_rounded)
        : !c.parked
        ? ('P단으로 바꾸면 이어서 해요', p.onWarning, Icons.pause_circle_rounded)
        : c.byTouch
        ? ('이 차에서는 화면 버튼으로 대신해요', p.description, Icons.touch_app_outlined)
        : c.alreadyOn
        ? ('이미 켜져 있어요. 한 번 껐다가 다시 켜 보세요', p.title, Icons.info_outline_rounded)
        : ('차에서 버튼을 눌러 보세요', p.title, Icons.radio_button_unchecked);
    return Row(
      children: [
        Icon(icon, size: 40 * s, color: color),
        SizedBox(width: 16 * s),
        Expanded(
          child: Text(
            keepWords(text),
            style: TextStyle(
              fontSize: 30 * s,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
