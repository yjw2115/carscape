import 'dart:ui' show ImageFilter;
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

/// 배지 half of the MY page: the tutorial badge and one per story (season 1)
/// in a single column of floating liquid-glass cards that pop in one by one.
class BadgeShelf extends StatefulWidget {
  const BadgeShelf({
    super.key,
    required this.progress,
    required this.s,
    required this.palette,
    this.stories = escapeThemes,
  });

  final Progress progress;
  final double s;
  final HomePalette palette;
  final List<EscapeTheme> stories;

  @override
  State<BadgeShelf> createState() => _BadgeShelfState();
}

class _BadgeShelfState extends State<BadgeShelf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  /// Each card springs up (slightly past full size) a beat after the last.
  Animation<double> _popFor(int i, int count) {
    final start = count < 2 ? 0.0 : 0.4 * i / (count - 1);
    return CurvedAnimation(
      parent: _pop,
      curve: Interval(start, start + 0.6, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final p = widget.palette;
    final progress = widget.progress;
    final stories = widget.stories;
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
    final sub = TextStyle(fontSize: 22 * s, color: p.description);

    return Stack(
      children: [
        // Soft color behind the glass so the cards have something to blur.
        Positioned.fill(child: CustomPaint(painter: _GlowPainter(p))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20 * s, 32 * s, 20 * s, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.military_tech_outlined,
                    size: 44 * s,
                    color: p.selectedBorder,
                  ),
                  SizedBox(width: 14 * s),
                  Text(
                    '배지',
                    style: TextStyle(
                      fontSize: 40 * s,
                      fontWeight: FontWeight.w600,
                      color: p.title,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 0),
              child: Text(
                '모은 배지 $earned / ${entries.length} · 금색 테두리 $gold',
                style: sub.copyWith(fontSize: 24 * s),
              ),
            ),
            Expanded(
              child: ListView(
                // Room for the cards' shadows and their spring past full size.
                padding: EdgeInsets.fromLTRB(20 * s, 24 * s, 20 * s, 24 * s),
                children: [
                  for (final (i, (id, title, lock)) in entries.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: 18 * s),
                      child: ScaleTransition(
                        scale: _popFor(i, entries.length),
                        child: _GlassBadgeCard(
                          s: s,
                          palette: p,
                          id: id,
                          title: title,
                          tier: progress.badge(id),
                          lock: lock,
                        ),
                      ),
                    ),
                  SizedBox(height: 6 * s),
                  Text(
                    '시즌 1 · 스토리 ${stories.length}편을 모두 모으면 시즌 완성 특별 배지 '
                    '($storiesEarned / ${stories.length})',
                    style: sub.copyWith(color: p.title),
                  ),
                  SizedBox(height: 14 * s),
                  Wrap(
                    spacing: 24 * s,
                    runSpacing: 10 * s,
                    children: [
                      for (final t in BadgeTier.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hexagon_outlined,
                              size: 26 * s,
                              color: _tierColor(t),
                            ),
                            SizedBox(width: 6 * s),
                            Flexible(
                              child: Text(
                                keepWords('${t.label} · ${t.rule}'),
                                style: sub,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One badge on a frosted, floating glass card, same recipe as the home's
/// [GlassLogo]: blur, a light diagonal tint, a bright rim and a deep shadow.
class _GlassBadgeCard extends StatelessWidget {
  const _GlassBadgeCard({
    required this.s,
    required this.palette,
    required this.id,
    required this.title,
    required this.tier,
    required this.lock,
  });

  final double s;
  final HomePalette palette;
  final String id;
  final String title;
  final BadgeTier? tier;
  final String? lock;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final t = tier;
    final radius = BorderRadius.circular(34 * s);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 40 * s,
            offset: Offset(0, 18 * s),
          ),
          if (t != null)
            BoxShadow(
              color: _tierColor(t).withValues(alpha: 0.3),
              blurRadius: 36 * s,
              spreadRadius: -4 * s,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24 * s, sigmaY: 24 * s),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 16 * s),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: p.glassBorder, width: 1.5 * s),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.glassTint, p.glassTintSoft, p.glassTint],
                stops: const [0, 0.6, 1],
              ),
            ),
            // Sheen along the top edge, like light on curved glass.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: Opacity(
              opacity: t == null ? 0.72 : 1,
              child: Row(
                children: [
                  BadgeMedal(id: id, tier: t, size: 92 * s, palette: p),
                  SizedBox(width: 28 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 30 * s,
                            fontWeight: FontWeight.w600,
                            color: p.title,
                          ),
                        ),
                        SizedBox(height: 6 * s),
                        Text(
                          keepWords(switch (t) {
                            final t? => '${t.label} 테두리',
                            null => lock ?? '도전해 보세요',
                          }),
                          style: TextStyle(
                            fontSize: 22 * s,
                            fontWeight: t == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                            color: t == null ? p.description : p.title,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16 * s),
                  Icon(
                    t == null
                        ? Icons.lock_outline_rounded
                        : Icons.check_circle_rounded,
                    size: 36 * s,
                    // The pale tier colors vanish on light glass; the medal's
                    // rim still shows the tier there.
                    color: t == null
                        ? p.description
                        : p == HomePalette.dark
                        ? _tierColor(t)
                        : p.selectedBorder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large blurred color pools behind the badge cards.
class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.palette);

  final HomePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = palette == HomePalette.dark;
    final pools = [
      (
        const Offset(0.85, 0.18),
        0.62,
        dark
            ? HyundaiColors.activeBlue.withValues(alpha: 0.40)
            : HyundaiColors.skyBlue.withValues(alpha: 0.85),
      ),
      (
        const Offset(0.12, 0.55),
        0.55,
        dark
            ? _gold.withValues(alpha: 0.26)
            : HyundaiColors.sand.withValues(alpha: 0.95),
      ),
      (
        const Offset(0.78, 0.88),
        0.5,
        dark
            ? HyundaiColors.skyBlue.withValues(alpha: 0.22)
            : HyundaiColors.activeBlue.withValues(alpha: 0.22),
      ),
    ];
    for (final (at, r, color) in pools) {
      final center = Offset(at.dx * size.width, at.dy * size.height);
      final radius = r * size.width;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.palette != palette;
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
