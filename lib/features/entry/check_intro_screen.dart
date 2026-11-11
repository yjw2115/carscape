import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/theme.dart';
import '../../vehicle/vehicle_service.dart';
import 'check_controller.dart';
import 'check_run_screen.dart';
import 'entry_layout.dart';

const vehicleCheckRoute = 'vehicle-check';

/// Opens the vehicle check (E2–E5) on its own. Completes when the player
/// leaves it; results are written to [session]. The caller decides what's next.
Future<void> openVehicleCheck(
  BuildContext context,
  VehicleService vehicle,
  GameSession session,
) {
  final controller = CheckController(vehicle, session)..runAutoCheck();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: vehicleCheckRoute),
      builder: (_) => CheckIntroScreen(controller: controller),
    ),
  );
}

/// E2 차량 점검 안내. The auto check (started by the caller) runs silently.
/// Owns [controller] for the whole check flow (E2–E5).
class CheckIntroScreen extends StatefulWidget {
  const CheckIntroScreen({super.key, required this.controller});
  final CheckController controller;

  @override
  State<CheckIntroScreen> createState() => _CheckIntroScreenState();
}

class _CheckIntroScreenState extends State<CheckIntroScreen> {
  CheckController get c => widget.controller;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => EntryLayout(
      vehicle: c.vehicle,
      sideWidth: 380,
      content: const [
        Text('VEHICLE CHECK', style: AppText.label),
        Text('시작 전에\n차량을 점검할게요', style: AppText.title),
        Text(
          '게임 중 버튼이 반응하지 않는 일이 없도록, 이 차의 장치가 잘 작동하는지 확인해요. 1분이면 끝나요.',
          style: TextStyle(color: Color(0xFFCFCBC2)),
        ),
        Callout('점검 항목은 매번 무작위로 정해져요. 게임 힌트가 아니니 편하게 따라 해주세요.'),
      ],
      actions: [
        FilledButton.icon(
          key: const Key('startCheck'),
          onPressed: c.autoFinished
              ? () {
                  c.startDirectCheck();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CheckRunScreen(controller: c),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.check_rounded),
          label: Text(c.autoFinished ? '점검 시작' : '자동 점검 중…'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('뒤로'),
        ),
      ],
      side: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            n: 1,
            title: '자동 점검',
            trailing: '${c.autoDone} / ${c.autoTotal}',
            body: '이 차가 어떤 장치를 지원하는지 앱이 알아서 확인해요. 할 일은 없어요.',
            progress: c.autoDone / c.autoTotal,
          ),
          const SizedBox(height: 12),
          const _Step(
            n: 2,
            title: '직접 점검',
            trailing: '최대 5개',
            body: '자동 점검에서 지원이 확인된 장치 중 몇 개를 골라, 버튼을 한 번씩 눌러 실제로 반응하는지 확인해요.',
          ),
          const SizedBox(height: 12),
          const Text(
            '작동하지 않는 장치가 있으면 그 부분은 화면 터치로 대신 진행돼요.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.trailing,
    required this.body,
    this.progress,
  });

  final int n;
  final String title;
  final String trailing;
  final String body;
  final double? progress;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.border,
              child: Text('$n', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              trailing,
              style: AppText.label.copyWith(
                letterSpacing: 0,
                color: progress == 1 ? AppColors.success : AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        if (progress != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: AppColors.success,
            backgroundColor: const Color(0xFF22252D),
          ),
        ],
      ],
    ),
  );
}
