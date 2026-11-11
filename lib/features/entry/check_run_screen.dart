import 'package:flutter/material.dart';
import '../../core/game_session.dart';
import '../../core/theme.dart';
import 'check_controller.dart';
import 'check_result_screen.dart';
import 'entry_layout.dart';

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
      if (id == null) return const Scaffold();
      final secs = c.waited.inSeconds;
      return EntryLayout(
        vehicle: c.vehicle,
        sideWidth: 300,
        content: [
          Text(
            'VEHICLE CHECK · ${c.index + 1} / ${c.plan.length}',
            style: AppText.label,
          ),
          Panel(
            key: ValueKey(id),
            border: c.detected ? AppColors.success : const Color(0xFF3A3220),
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF231C12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.touch_app_outlined,
                    size: 40,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(height: 14),
                Text(id.prompt, style: AppText.title),
                const SizedBox(height: 10),
                if (_showWhere)
                  Text(
                    id.where,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                const SizedBox(height: 18),
                _WaitBar(
                  detected: c.detected,
                  paused: !c.parked,
                  time:
                      '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ],
        actions: [
          OutlinedButton(
            onPressed: c.detected ? null : c.skip,
            child: const Text('이 항목 건너뛰기'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showWhere = true),
            icon: const Icon(Icons.help_outline),
            label: const Text('어디 있나요?'),
          ),
        ],
        side: _CheckList(c),
        overlay: c.timedOut ? _RetryOverlay(c) : null,
      );
    },
  );
}

class _WaitBar extends StatelessWidget {
  const _WaitBar({
    required this.detected,
    required this.paused,
    required this.time,
  });
  final bool detected;
  final bool paused;
  final String time;

  @override
  Widget build(BuildContext context) {
    final (text, color) = detected
        ? ('정상 반응을 확인했어요', AppColors.success)
        : paused
        ? ('P단으로 바꾸면 이어서 점검해요', AppColors.warning)
        : ('조작을 기다리는 중…', const Color(0xFFF2DDB4));
    return Panel(
      color: const Color(0xFF0F1014),
      border: const Color(0xFF4A3D28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.circle,
            size: 14,
            color: detected ? AppColors.success : AppColors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            time,
            style: AppText.label.copyWith(
              letterSpacing: 0,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming items stay hidden until their turn.
class _CheckList extends StatelessWidget {
  const _CheckList(this.c);
  final CheckController c;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.all(4),
        child: Text(
          '점검 목록',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ),
      for (final (i, id) in c.plan.indexed) ...[
        const SizedBox(height: 8),
        _row(i, i <= c.index ? id.label : '다음 항목', _state(i)),
      ],
      const Padding(
        padding: EdgeInsets.all(4),
        child: Text(
          '다음 항목은 차례가 되면 공개돼요',
          style: TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      ),
    ],
  );

  (String, Color)? _state(int i) {
    if (i > c.index) return null;
    final id = c.plan[i];
    return switch (c.session.devices[id]) {
      DeviceStatus.verified => ('정상', AppColors.success),
      DeviceStatus.fallback => ('화면 터치로', AppColors.warning),
      _ when c.skipped.contains(id) => ('건너뜀', AppColors.muted),
      _ => ('확인 중', AppColors.amber),
    };
  }

  Widget _row(int i, String label, (String, Color)? state) {
    final color = state?.$2 ?? AppColors.faint;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state == null
            ? const Color(0xFF111216)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state == null ? const Color(0xFF22252D) : color,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.transparent,
            foregroundColor: color,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: state == null ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
          if (state != null)
            Text(state.$1, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _RetryOverlay extends StatelessWidget {
  const _RetryOverlay(this.c);
  final CheckController c;

  @override
  Widget build(BuildContext context) {
    final canRetry = c.attempt < maxAttempts;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xC7050507),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Panel(
                border: const Color(0xFF5A3A2A),
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: Color(0xFFFF9A84),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${c.current!.label} 조작이\n감지되지 않았어요',
                      style: AppText.title.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 12),
                    for (final tip in const [
                      '버튼을 끝까지 눌렀는지 확인해주세요',
                      '시동(전원)이 켜져 있어야 감지돼요',
                      '신호가 늦게 들어올 수 있어요. 잠시 후 다시 눌러주세요',
                    ])
                      Text(
                        '·  $tip',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFCFCBC2),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '시도 ${c.attempt} / $maxAttempts',
                      style: AppText.label.copyWith(
                        letterSpacing: 0,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '"없이 진행"을 고르면, 게임에서 이 장치가 필요한 순간 화면 터치로 대신 진행돼요.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (canRetry)
                          FilledButton.icon(
                            key: const Key('retry'),
                            onPressed: c.retry,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('다시 해보기'),
                          ),
                        OutlinedButton(
                          key: const Key('without'),
                          onPressed: c.proceedWithout,
                          child: const Text('이 장치 없이 진행'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
