import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';
import '../../vehicle/fake_vehicle_panel.dart';
import '../../vehicle/vehicle_service.dart';
import '../home/presentation/home_palette.dart';
import 'check_controller.dart';
import 'check_run_screen.dart';

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

/// Dev-only "가짜 차량" button in the top-right corner of a check screen.
List<Widget> fakeVehicleCorner(VehicleService vehicle, double s) => [
  Positioned(top: 8 * s, right: 8 * s, child: FakeVehicleButton(vehicle)),
];

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

  void _start() {
    c.startDirectCheck();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CheckRunScreen(controller: c)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => RailPage(
      title: '시작 전에 차량을 점검할게요',
      backLabel: '뒤로',
      rail: (s, p) => [
        RailAction(
          key: const Key('startCheck'),
          s: s,
          palette: p,
          primary: true,
          icon: Icons.play_arrow_rounded,
          label: c.autoFinished ? '점검 시작' : '자동 점검 중',
          onTap: c.autoFinished ? _start : null,
        ),
      ],
      overlay: (s, _) => fakeVehicleCorner(c.vehicle, s),
      body: (s, p) {
        final text = TextStyle(fontSize: 30 * s, color: p.description);
        return ListView(
          children: [
            Text(
              '게임 중 버튼이 반응하지 않는 일이 없도록, 이 차의 장치가 잘 작동하는지 확인해요. 1분이면 끝나요.',
              style: text,
            ),
            SizedBox(height: 32 * s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Step(
                    s: s,
                    palette: p,
                    n: 1,
                    title: '자동 점검',
                    trailing: '${c.autoDone} / ${c.autoTotal}',
                    body: '이 차가 어떤 장치를 지원하는지 앱이 알아서 확인해요. 할 일은 없어요.',
                    progress: c.autoDone / c.autoTotal,
                  ),
                ),
                SizedBox(width: 24 * s),
                Expanded(
                  child: _Step(
                    s: s,
                    palette: p,
                    n: 2,
                    title: '직접 점검',
                    trailing: '최대 5개',
                    body: '지원이 확인된 장치 중 몇 개를 골라, 버튼을 한 번씩 눌러 실제로 반응하는지 확인해요.',
                  ),
                ),
              ],
            ),
            SizedBox(height: 24 * s),
            RailCard(
              s: s,
              palette: p,
              child: Text(
                '점검 항목은 매번 무작위로 정해져요. 게임 힌트가 아니니 편하게 따라 해주세요. '
                '작동하지 않는 장치는 게임에서 화면 터치로 대신 진행돼요.',
                style: text.copyWith(fontSize: 26 * s),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.s,
    required this.palette,
    required this.n,
    required this.title,
    required this.trailing,
    required this.body,
    this.progress,
  });

  final double s;
  final HomePalette palette;
  final int n;
  final String title;
  final String trailing;
  final String body;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return RailCard(
      s: s,
      palette: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22 * s,
                backgroundColor: p.chip,
                child: Text(
                  '$n',
                  style: TextStyle(fontSize: 24 * s, color: p.onChip),
                ),
              ),
              SizedBox(width: 16 * s),
              Text(
                title,
                style: TextStyle(
                  fontSize: 32 * s,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
              const Spacer(),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 26 * s,
                  color: progress == 1
                      ? HyundaiColors.activeBlue
                      : p.description,
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * s),
          Text(
            body,
            style: TextStyle(fontSize: 26 * s, color: p.description),
          ),
          if (progress != null) ...[
            SizedBox(height: 20 * s),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10 * s,
              borderRadius: BorderRadius.circular(5 * s),
              color: HyundaiColors.activeBlue,
              backgroundColor: p.chip,
            ),
          ],
        ],
      ),
    );
  }
}
