import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';
import '../home/presentation/home_palette.dart';
import 'check_controller.dart';
import 'check_intro_screen.dart';
import 'check_run_screen.dart';

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
    return RailPage(
      title: '점검이 끝났어요',
      backLabel: null,
      rail: (s, p) => [
        RailAction(
          key: const Key('checkDone'),
          s: s,
          palette: p,
          primary: true,
          icon: Icons.check_rounded,
          label: '완료',
          onTap: () => Navigator.of(context)
            ..popUntil(ModalRoute.withName(vehicleCheckRoute))
            ..pop(),
        ),
        RailAction(
          s: s,
          palette: p,
          icon: Icons.replay_rounded,
          label: '다시 점검',
          onTap: () {
            c.startDirectCheck();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => CheckRunScreen(controller: c),
              ),
            );
          },
        ),
      ],
      overlay: (s, _) => fakeVehicleCorner(c.vehicle, s),
      body: (s, p) {
        return ListView(
          children: [
            if (missing > 0) ...[
              Container(
                padding: EdgeInsets.all(28 * s),
                decoration: BoxDecoration(
                  color: p.warning,
                  borderRadius: BorderRadius.circular(22 * s),
                  border: Border.all(color: p.warningBorder, width: 2 * s),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 44 * s,
                      color: p.onWarning,
                    ),
                    SizedBox(width: 18 * s),
                    Expanded(
                      child: Text(
                        '쓸 수 없는 장치 $missing개는 화면 터치로 대신해요',
                        style: TextStyle(
                          fontSize: 30 * s,
                          fontWeight: FontWeight.w500,
                          color: p.onWarning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24 * s),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Stat(
                    s: s,
                    palette: p,
                    title: '지원 장치',
                    value: c.supportedCount,
                    total: c.autoTotal,
                  ),
                ),
                SizedBox(width: 24 * s),
                Expanded(
                  child: _Stat(
                    s: s,
                    palette: p,
                    title: '정상 작동',
                    value: c.verifiedCount,
                    total: c.plan.length,
                  ),
                ),
                SizedBox(width: 24 * s),
                Expanded(
                  flex: 2,
                  child: RailCard(
                    s: s,
                    palette: p,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '직접 점검',
                          style: TextStyle(
                            fontSize: 28 * s,
                            fontWeight: FontWeight.w600,
                            color: p.title,
                          ),
                        ),
                        for (final id in c.plan) ...[
                          SizedBox(height: 14 * s),
                          _itemLine(
                            s,
                            p,
                            id.label,
                            c.session.devices[id],
                            c.skipped.contains(id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _itemLine(
    double s,
    HomePalette p,
    String label,
    DeviceStatus? status,
    bool skipped,
  ) {
    final (icon, color, note) = switch (status) {
      DeviceStatus.verified => (
        Icons.check_rounded,
        HyundaiColors.activeBlue,
        '',
      ),
      DeviceStatus.fallback => (Icons.touch_app_outlined, p.onWarning, '화면 터치'),
      _ => (Icons.remove_rounded, p.description, skipped ? '건너뜀' : ''),
    };
    return Row(
      children: [
        Icon(icon, size: 36 * s, color: color),
        SizedBox(width: 16 * s),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 28 * s, color: p.title),
          ),
        ),
        if (note.isNotEmpty)
          Text(
            note,
            style: TextStyle(
              fontSize: 26 * s,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.s,
    required this.palette,
    required this.title,
    required this.value,
    required this.total,
  });

  final double s;
  final HomePalette palette;
  final String title;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return RailCard(
      s: s,
      palette: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 28 * s,
              fontWeight: FontWeight.w500,
              color: p.title,
            ),
          ),
          SizedBox(height: 8 * s),
          Text.rich(
            TextSpan(
              text: '$value',
              style: TextStyle(
                fontSize: 64 * s,
                fontWeight: FontWeight.w600,
                color: p.title,
              ),
              children: [
                TextSpan(
                  text: ' / $total',
                  style: TextStyle(fontSize: 32 * s, color: p.description),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
