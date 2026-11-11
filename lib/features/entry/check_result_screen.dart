import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/theme.dart';
import '../../vehicle/device_catalog.dart';
import 'check_controller.dart';
import 'check_intro_screen.dart';
import 'check_run_screen.dart';
import 'entry_layout.dart';

/// E5 점검 결과. Never says which puzzle uses which device.
class CheckResultScreen extends StatelessWidget {
  const CheckResultScreen({super.key, required this.controller});
  final CheckController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final missing = c.session.devices.values
        .where(
          (s) => s == DeviceStatus.unsupported || s == DeviceStatus.fallback,
        )
        .length;
    return EntryLayout(
      vehicle: c.vehicle,
      background: const RadialGradient(
        center: Alignment(-0.5, -0.4),
        radius: 1.2,
        colors: [Color(0xFF12201A), AppColors.background],
        stops: [0, 0.6],
      ),
      content: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xFF13241B),
          child: Icon(Icons.check_rounded, size: 32, color: AppColors.success),
        ),
        Text(
          'CHECK COMPLETE',
          style: AppText.label.copyWith(color: AppColors.success),
        ),
        const Text('점검이 끝났어요\n플레이할 준비 완료!', style: AppText.title),
        if (missing > 0)
          Callout(
            '이 차에서 쓸 수 없는 장치가 $missing개 있어요. 필요한 순간에는 화면 터치로 대신 진행돼요.',
            warn: true,
          ),
      ],
      actions: [
        FilledButton.icon(
          key: const Key('checkDone'),
          onPressed: () => Navigator.of(context)
            ..popUntil(ModalRoute.withName(vehicleCheckRoute))
            ..pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('완료'),
        ),
        OutlinedButton(
          onPressed: () {
            c.startDirectCheck();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => CheckRunScreen(controller: c),
              ),
            );
          },
          child: const Text('다시 점검'),
        ),
      ],
      side: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat('자동 점검', c.supportedCount, c.autoTotal, '지원되는 장치'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat('직접 점검', c.verifiedCount, c.plan.length, '정상 반응'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '직접 점검한 항목',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                for (final id in c.plan) ...[
                  const SizedBox(height: 8),
                  _ItemLine(id, c),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.value, this.total, this.caption);
  final String title;
  final int value;
  final int total;
  final String caption;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        Text.rich(
          TextSpan(
            text: '$value',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(
                text: ' / $total',
                style: const TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ItemLine extends StatelessWidget {
  const _ItemLine(this.id, this.c);
  final DeviceId id;
  final CheckController c;

  @override
  Widget build(BuildContext context) {
    final (icon, color, note) = switch (c.session.devices[id]) {
      DeviceStatus.verified => (Icons.check_rounded, AppColors.success, ''),
      DeviceStatus.fallback => (
        Icons.touch_app_outlined,
        AppColors.warning,
        ' · 화면 터치로',
      ),
      _ => (Icons.remove_rounded, AppColors.amber, ' · 건너뜀'),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          '${id.label}$note',
          style: TextStyle(
            fontSize: 15,
            color: note.isEmpty ? AppColors.text : AppColors.muted,
          ),
        ),
      ],
    );
  }
}
