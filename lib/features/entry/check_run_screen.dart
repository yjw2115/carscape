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
        title: '기능점검 · ${c.index + 1} / ${c.plan.length}',
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
                    SizedBox(height: 12 * s),
                    Text(
                      '조금만 바꿔도 바로 확인돼요. 끝까지 하지 않아도 돼요.',
                      style: TextStyle(fontSize: 32 * s, color: p.description),
                    ),
                    SizedBox(height: 20 * s),
                    // Asked for with 어디 있나요?; the space stays reserved
                    // so the card doesn't jump.
                    Opacity(
                      opacity: _showWhere ? 1 : 0,
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 40 * s,
                            color: p.title,
                          ),
                          SizedBox(width: 12 * s),
                          Expanded(
                            child: Text(
                              id.where,
                              style: TextStyle(
                                fontSize: 32 * s,
                                color: p.title,
                              ),
                            ),
                          ),
                        ],
                      ),
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
        ? ('정상 작동', HyundaiColors.activeBlue, p.checking)
        : paused
        ? ('P단으로 바꾸면 이어서 점검해요', p.onWarning, p.warning)
        : ('조작 대기 중', p.title, p.checking);
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

class _CheckList extends StatelessWidget {
  const _CheckList({required this.c, required this.s, required this.palette});
  final CheckController c;
  final double s;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, id) in c.plan.indexed) ...[
        if (i > 0) SizedBox(height: 14 * s),
        _row(i, id),
      ],
    ],
  );

  Widget _row(int i, DeviceId id) {
    final p = palette;
    final open = i <= c.index;
    final (note, color) = !open
        ? ('', p.description)
        : switch (c.session.devices[id]) {
            DeviceStatus.verified => ('정상', HyundaiColors.activeBlue),
            DeviceStatus.fallback => ('화면 터치', p.onWarning),
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
          // Upcoming items stay hidden until their turn.
          if (open)
            Text(
              note,
              style: TextStyle(
                fontSize: 26 * s,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            )
          else
            Icon(Icons.lock_outline_rounded, size: 30 * s, color: color),
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
                  SizedBox(height: 24 * s),
                  Text(
                    '한 번만 바꿔도 돼요. 시동이 켜져 있는지 확인하고 다시 해보세요',
                    style: TextStyle(fontSize: 30 * s, color: p.title),
                  ),
                  SizedBox(height: 24 * s),
                  StatusChip(
                    s: s,
                    palette: p,
                    label: '시도 ${c.attempt} / $maxAttempts',
                    tone: canRetry ? ChipTone.neutral : ChipTone.warning,
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
                        '화면 터치로 대신하기',
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
