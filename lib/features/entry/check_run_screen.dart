import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/rail_page.dart';
import '../../vehicle/device_catalog.dart';
import '../home/presentation/home_palette.dart';
import 'check_controller.dart';
import 'check_intro_screen.dart';
import 'check_result_screen.dart';

/// E3 점검 진행 + E4 감지 실패·재시도 (overlay). Push after
/// [CheckController.startDirectCheck].
class CheckRunScreen extends StatefulWidget {
  const CheckRunScreen({super.key, required this.controller});
  final CheckController controller;

  @override
  State<CheckRunScreen> createState() => _CheckRunScreenState();
}

class _CheckRunScreenState extends State<CheckRunScreen> {
  CheckController get c => widget.controller;
  bool _showWhere = false;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  void _changed() {
    if (c.index != _lastIndex) {
      _lastIndex = c.index;
      _showWhere = false;
    }
    if (c.finished) {
      c.removeListener(_changed);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CheckResultScreen(controller: c),
        ),
      );
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final id = c.current;
      if (id == null) return const SizedBox.shrink();
      final secs = c.waited.inSeconds;
      return RailPage(
        title: '차량 점검 · ${c.index + 1} / ${c.plan.length}',
        backLabel: '뒤로',
        rail: (s, p) => [
          RailAction(
            s: s,
            palette: p,
            icon: Icons.skip_next_rounded,
            label: '건너뛰기',
            onTap: c.detected ? null : c.skip,
          ),
          RailAction(
            s: s,
            palette: p,
            icon: Icons.help_outline_rounded,
            label: '어디 있나요?',
            onTap: () => setState(() => _showWhere = true),
          ),
        ],
        overlay: (s, p) => [
          if (c.timedOut) _RetryOverlay(c: c, s: s, palette: p),
          ...fakeVehicleCorner(c.vehicle, s),
        ],
        body: (s, p) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RailCard(
                key: ValueKey(id),
                s: s,
                palette: p,
                highlight: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 80 * s,
                      color: p.title,
                    ),
                    SizedBox(height: 24 * s),
                    Text(
                      id.prompt,
                      style: TextStyle(
                        fontSize: 52 * s,
                        fontWeight: FontWeight.w600,
                        color: p.title,
                      ),
                    ),
                    SizedBox(height: 16 * s),
                    Text(
                      _showWhere ? id.where : '',
                      style: TextStyle(fontSize: 28 * s, color: p.description),
                    ),
                    SizedBox(height: 40 * s),
                    _WaitBar(
                      s: s,
                      palette: p,
                      detected: c.detected,
                      paused: !c.parked,
                      time:
                          '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 32 * s),
            SizedBox(
              width: 420 * s,
              child: _CheckList(c: c, s: s, palette: p),
            ),
          ],
        ),
      );
    },
  );
}

class _WaitBar extends StatelessWidget {
  const _WaitBar({
    required this.s,
    required this.palette,
    required this.detected,
    required this.paused,
    required this.time,
  });

  final double s;
  final HomePalette palette;
  final bool detected;
  final bool paused;
  final String time;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final (text, color, bg) = detected
        ? ('정상 반응을 확인했어요', HyundaiColors.activeBlue, p.checking)
        : paused
        ? ('P단으로 바꾸면 이어서 점검해요', p.onWarning, p.warning)
        : ('조작을 기다리는 중…', p.title, p.checking);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 24 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22 * s),
        border: paused && !detected
            ? Border.all(color: p.warningBorder, width: 2 * s)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle_rounded : Icons.circle,
            size: detected ? 36 * s : 20 * s,
            color: color,
          ),
          SizedBox(width: 18 * s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 30 * s,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 28 * s,
              color: p.description,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming items stay hidden until their turn.
class _CheckList extends StatelessWidget {
  const _CheckList({required this.c, required this.s, required this.palette});
  final CheckController c;
  final double s;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '점검 목록',
          style: TextStyle(fontSize: 26 * s, color: p.description),
        ),
        for (final (i, id) in c.plan.indexed) ...[
          SizedBox(height: 14 * s),
          _row(i, id),
        ],
        SizedBox(height: 14 * s),
        Text(
          '다음 항목은 차례가 되면 공개돼요',
          style: TextStyle(fontSize: 22 * s, color: p.description),
        ),
      ],
    );
  }

  Widget _row(int i, DeviceId id) {
    final p = palette;
    final open = i <= c.index;
    final (note, color) = !open
        ? ('', p.description)
        : switch (c.session.devices[id]) {
            DeviceStatus.verified => ('정상', HyundaiColors.activeBlue),
            DeviceStatus.fallback => ('화면 터치로', p.onWarning),
            _ when c.skipped.contains(id) => ('건너뜀', p.description),
            _ => ('확인 중', p.title),
          };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 20 * s),
      decoration: BoxDecoration(
        color: open ? p.card : p.checking,
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(
          color: i == c.index ? p.selectedBorder : p.cardBorder,
          width: (i == c.index ? 3 : 1.5) * s,
        ),
      ),
      child: Row(
        children: [
          Text(
            '${i + 1}',
            style: TextStyle(fontSize: 26 * s, color: p.description),
          ),
          SizedBox(width: 18 * s),
          Expanded(
            child: Text(
              open ? id.label : '다음 항목',
              style: TextStyle(
                fontSize: 28 * s,
                fontWeight: open ? FontWeight.w600 : FontWeight.w400,
                color: open ? p.title : p.description,
              ),
            ),
          ),
          Text(
            note,
            style: TextStyle(fontSize: 24 * s, color: color),
          ),
        ],
      ),
    );
  }
}

/// E4: no reaction for 20 s. Buttons stay on the driver side (left).
class _RetryOverlay extends StatelessWidget {
  const _RetryOverlay({
    required this.c,
    required this.s,
    required this.palette,
  });
  final CheckController c;
  final double s;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final canRetry = c.attempt < maxAttempts;
    final text = TextStyle(fontSize: 28 * s, color: p.description);
    Widget button(Key key, String label, VoidCallback onTap, bool primary) =>
        Expanded(
          child: RailAction(
            key: key,
            s: s,
            palette: p,
            height: 130,
            label: label,
            primary: primary,
            onTap: onTap,
          ),
        );
    return Positioned.fill(
      child: ColoredBox(
        color: p.shadow,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(32 * s),
            child: Container(
              width: 900 * s,
              padding: EdgeInsets.all(48 * s),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(36 * s),
                border: Border.all(color: p.warningBorder, width: 2 * s),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 72 * s,
                    color: p.onWarning,
                  ),
                  SizedBox(height: 20 * s),
                  Text(
                    '${c.current!.label} 조작이 감지되지 않았어요',
                    style: TextStyle(
                      fontSize: 48 * s,
                      fontWeight: FontWeight.w600,
                      color: p.title,
                    ),
                  ),
                  SizedBox(height: 20 * s),
                  for (final tip in const [
                    '버튼을 끝까지 눌렀는지 확인해주세요',
                    '시동(전원)이 켜져 있어야 감지돼요',
                    '신호가 늦게 들어올 수 있어요. 잠시 후 다시 눌러주세요',
                  ])
                    Text('·  $tip', style: text),
                  SizedBox(height: 20 * s),
                  Text('시도 ${c.attempt} / $maxAttempts', style: text),
                  Text(
                    '"이 장치 없이 진행"을 고르면, 게임에서 이 장치가 필요한 순간 화면 터치로 대신 진행돼요.',
                    style: text.copyWith(fontSize: 24 * s),
                  ),
                  SizedBox(height: 36 * s),
                  Row(
                    children: [
                      if (canRetry) ...[
                        button(const Key('retry'), '다시 해보기', c.retry, true),
                        SizedBox(width: 20 * s),
                      ],
                      button(
                        const Key('without'),
                        '이 장치 없이 진행',
                        c.proceedWithout,
                        !canRetry,
                      ),
                    ],
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
