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
      title: '기능점검',
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
      body: (s, p) => ListView(
        children: [
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
                  icon: Icons.touch_app_outlined,
                  trailing: '최대 5개',
                  body: '버튼을 한 번씩 눌러요',
                ),
              ),
            ],
          ),
        ],
      ),
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
    this.icon,
    this.body,
    this.progress,
  });

  final double s;
  final HomePalette palette;
  final int n;
  final IconData? icon;
  final String title;
  final String trailing;
  final String? body;
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
              StatusChip(
                s: s,
                palette: p,
                label: trailing,
                tone: progress == 1 ? ChipTone.ok : ChipTone.neutral,
              ),
            ],
          ),
          SizedBox(height: 28 * s),
          if (body case final body?)
            Row(
              children: [
                Icon(icon, size: 40 * s, color: p.title),
                SizedBox(width: 14 * s),
                Text(
                  body,
                  style: TextStyle(fontSize: 30 * s, color: p.title),
                ),
              ],
            ),
          if (progress != null) ...[
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
