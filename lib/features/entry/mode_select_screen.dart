import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/theme.dart';
import '../../vehicle/device_catalog.dart';
import '../../vehicle/fake_vehicle_panel.dart';
import '../../vehicle/vehicle_service.dart';
import '../tutorial/presentation/tutorial_screen.dart';
import '../tutorial/presentation/tutorial_style.dart';
import 'check_intro_screen.dart';

/// E1 모드 선택.
class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({
    super.key,
    required this.vehicle,
    required this.session,
  });
  final VehicleService vehicle;
  final GameSession session;

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  late final Stream<VehicleReading> _gear = widget.vehicle.watch(DeviceId.gear);

  void _startTutorial() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Theme(
        data: tutorialTheme(),
        child: TutorialScreen(onFinished: (_) => Navigator.of(context).pop()),
      ),
    ),
  );

  Future<void> _openCheck() async {
    await openVehicleCheck(context, widget.vehicle, widget.session);
    if (mounted) setState(() {});
  }

  String get _checkStatus {
    final devices = widget.session.devices;
    if (devices.isEmpty) return '아직 차량 점검 전이에요';
    final missing = devices.values
        .where(
          (s) => s == DeviceStatus.unsupported || s == DeviceStatus.fallback,
        )
        .length;
    return missing == 0 ? '차량 점검 완료' : '차량 점검 완료 · 화면 터치 대체 $missing개';
  }

  void _notReady() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ModeCard(
        key: const Key('tutorial'),
        tag: 'TUTORIAL',
        title: '얼어붙은 밤',
        body: '차의 버튼으로 퍼즐을 푸는 법을 익혀요',
        chips: const ['약 15분', '2~4인', '실패 없음'],
        accent: AppColors.ice,
        badge: '처음이라면 여기서',
        onTap: _startTutorial,
      ),
      const _ModeCard(
        tag: 'CASE 01',
        title: '[본편 시나리오]',
        body: '본격 방탈출 · 시간 제한과 힌트 제한',
        chips: ['약 30분', '[인원]'],
        accent: AppColors.muted,
        lockedText: '튜토리얼을 마치면 열려요',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 740;
            final header = Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: AppColors.amber),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '무엇을 플레이할까요?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
                StreamBuilder(
                  stream: _gear,
                  builder: (_, s) => _GearBadge(
                    parked: !s.hasData || s.data!.value == gearPark,
                  ),
                ),
                const SizedBox(width: 120),
              ],
            );
            final footer = Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('openCheck'),
                  onPressed: _openCheck,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('차량 점검'),
                ),
                OutlinedButton.icon(
                  onPressed: _notReady,
                  icon: const Icon(
                    Icons.hexagon_outlined,
                    color: AppColors.gold,
                  ),
                  label: const Text('배지판'),
                ),
                OutlinedButton.icon(
                  onPressed: _notReady,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('설정'),
                ),
                Text(
                  _checkStatus,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            );
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 16 : 32,
                    vertical: narrow ? 16 : 24,
                  ),
                  child: narrow
                      ? ListView(
                          children: [
                            header,
                            for (final card in cards) ...[
                              const SizedBox(height: 16),
                              SizedBox(height: 340, child: card),
                            ],
                            const SizedBox(height: 16),
                            footer,
                          ],
                        )
                      : Column(
                          children: [
                            header,
                            const SizedBox(height: 18),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 16),
                                  Expanded(child: cards[1]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: footer,
                            ),
                          ],
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: FakeVehicleButton(widget.vehicle),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GearBadge extends StatelessWidget {
  const _GearBadge({required this.parked});
  final bool parked;

  @override
  Widget build(BuildContext context) {
    final color = parked ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            parked ? 'P단 · 플레이 가능' : 'P단으로 바꿔주세요',
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.tag,
    required this.title,
    required this.body,
    required this.chips,
    required this.accent,
    this.badge,
    this.lockedText,
    this.onTap,
  });

  final String tag;
  final String title;
  final String body;
  final List<String> chips;
  final Color accent;
  final String? badge;
  final String? lockedText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lockedText != null;
    return Material(
      color: locked ? const Color(0xFF111216) : const Color(0xFF0A111B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: locked ? AppColors.border : accent,
          width: locked ? 1 : 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: locked
                    ? const Color(0xFF0B1218)
                    : const Color(0xFF0C1520),
                padding: const EdgeInsets.all(14),
                alignment: locked ? Alignment.center : Alignment.topLeft,
                child: locked
                    ? _Chip(lockedText!, icon: Icons.lock_outline)
                    : _Chip(badge!, filled: accent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag,
                    style: AppText.label.copyWith(color: accent, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: locked ? AppColors.muted : AppColors.text,
                    ),
                  ),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, children: [for (final c in chips) _Chip(c)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.filled, this.icon});
  final String text;
  final Color? filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: filled ?? const Color(0xFF1A1B20),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: filled != null ? FontWeight.w700 : FontWeight.w400,
            color: filled != null
                ? const Color(0xFF06141C)
                : const Color(0xFFCFE0EA),
          ),
        ),
      ],
    ),
  );
}
