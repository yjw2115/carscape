import 'package:flutter/material.dart';
import '../../core/rail_page.dart';
import '../home/domain/escape_theme.dart';
import '../home/presentation/home_palette.dart';
import 'progress.dart';

const _gold = Color(0xFFE8C26A);
const _silver = Color(0xFFC9D1DA);

Color _tierColor(BadgeTier t) => switch (t) {
  BadgeTier.basic => HyundaiColors.sand,
  BadgeTier.silver => _silver,
  BadgeTier.gold => _gold,
};

/// Motif per badge (docs/handoff.md §7: 눈송이, 빗방울 …).
IconData _motif(String id) => switch (id) {
  tutorialBadgeId => Icons.school_outlined,
  storyFrozenNight => Icons.ac_unit_rounded,
  'case01' => Icons.water_drop_outlined,
  'case02' => Icons.local_parking_rounded,
  'case03' => Icons.explore_outlined,
  _ => Icons.star_outline_rounded,
};

/// Hexagon badge. A null [tier] draws the not-yet-earned silhouette.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.id,
    required this.tier,
    required this.size,
    required this.palette,
  });

  final String id;
  final BadgeTier? tier;
  final double size;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = tier;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: t == null ? palette.checking : palette.button,
        shape: StarBorder.polygon(
          sides: 6,
          rotation: 30,
          pointRounding: 0.2,
          side: BorderSide(
            color: t == null ? palette.cardBorder : _tierColor(t),
            width: size * (t == BadgeTier.basic || t == null ? 0.03 : 0.07),
          ),
        ),
      ),
      child: t == null
          ? Text(
              '?',
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
                color: palette.description,
              ),
            )
          : Icon(_motif(id), size: size * 0.42, color: HyundaiColors.lightSand),
    );
  }
}

/// 배지판: the tutorial badge and one per story (season 1).
class BadgeBookPage extends StatelessWidget {
  const BadgeBookPage({
    super.key,
    required this.progress,
    this.stories = escapeThemes,
  });

  final Progress progress;
  final List<EscapeTheme> stories;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        tutorialBadgeId,
        '기본 훈련',
        progress.tutorialDone ? null : '튜토리얼을 마치면 받아요',
      ),
      for (final st in stories) (st.id, st.title, progress.lockedReason(st.id)),
    ];
    final earned = entries.where((e) => progress.badge(e.$1) != null).length;
    final gold = entries
        .where((e) => progress.badge(e.$1) == BadgeTier.gold)
        .length;
    final storiesEarned = stories
        .where((st) => progress.badge(st.id) != null)
        .length;
    return RailPage(
      title: '배지판',
      body: (s, p) {
        final sub = TextStyle(fontSize: 26 * s, color: p.description);
        return ListView(
          children: [
            Text(
              '모은 배지 $earned / ${entries.length} · 금색 테두리 $gold',
              style: sub.copyWith(fontSize: 30 * s),
            ),
            SizedBox(height: 32 * s),
            Wrap(
              spacing: 24 * s,
              runSpacing: 24 * s,
              children: [
                for (final (id, title, lock) in entries)
                  SizedBox(
                    width: 290 * s,
                    child: RailCard(
                      s: s,
                      palette: p,
                      child: Column(
                        children: [
                          BadgeMedal(
                            id: id,
                            tier: progress.badge(id),
                            size: 150 * s,
                            palette: p,
                          ),
                          SizedBox(height: 18 * s),
                          Text(
                            keepWords(title),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28 * s,
                              fontWeight: FontWeight.w600,
                              color: p.title,
                            ),
                          ),
                          SizedBox(height: 6 * s),
                          Text(
                            keepWords(switch (progress.badge(id)) {
                              final t? => '${t.label} 테두리',
                              null => lock ?? '도전해 보세요',
                            }),
                            textAlign: TextAlign.center,
                            style: sub.copyWith(fontSize: 22 * s),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 32 * s),
            RailCard(
              s: s,
              palette: p,
              child: Text(
                '시즌 1 · 스토리 ${stories.length}편을 모두 모으면 시즌 완성 특별 배지 '
                '($storiesEarned / ${stories.length})',
                style: sub.copyWith(color: p.title),
              ),
            ),
            SizedBox(height: 24 * s),
            Wrap(
              spacing: 32 * s,
              runSpacing: 12 * s,
              children: [
                for (final t in BadgeTier.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hexagon_outlined,
                        size: 32 * s,
                        color: _tierColor(t),
                      ),
                      SizedBox(width: 8 * s),
                      Text(
                        '${t.label} · ${t.rule}',
                        style: sub.copyWith(fontSize: 22 * s),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 배지 획득: shown right after a badge is earned or upgraded.
class BadgeGetPage extends StatelessWidget {
  const BadgeGetPage({
    super.key,
    required this.id,
    required this.name,
    required this.tier,
  });

  final String id;
  final String name;
  final BadgeTier tier;

  @override
  Widget build(BuildContext context) => RailPage(
    title: '새 배지를 획득했어요!',
    backLabel: null,
    rail: (s, p) => [
      RailAction(
        key: const Key('badgeContinue'),
        s: s,
        palette: p,
        primary: true,
        icon: Icons.arrow_forward_rounded,
        label: '계속',
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
    body: (s, p) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BadgeMedal(id: id, tier: tier, size: 360 * s, palette: p),
        SizedBox(width: 56 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name 배지',
                style: TextStyle(
                  fontSize: 52 * s,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
              Text(
                '${tier.label} 테두리',
                style: TextStyle(fontSize: 34 * s, color: _tierColor(tier)),
              ),
              SizedBox(height: 40 * s),
              if (id != tutorialBadgeId)
                for (final t in BadgeTier.values)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16 * s),
                    child: Row(
                      children: [
                        Icon(
                          t.index <= tier.index
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 36 * s,
                          color: t.index <= tier.index
                              ? _tierColor(t)
                              : p.description,
                        ),
                        SizedBox(width: 16 * s),
                        Text(
                          '${t.rule} · ${t.label} 테두리',
                          style: TextStyle(fontSize: 28 * s, color: p.title),
                        ),
                      ],
                    ),
                  )
              else
                Text(
                  '튜토리얼을 마쳤어요. 이제 첫 번째 스토리 "얼어붙은 밤"을 플레이할 수 있어요.',
                  style: TextStyle(fontSize: 28 * s, color: p.description),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
