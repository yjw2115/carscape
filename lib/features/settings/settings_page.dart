import 'package:flutter/material.dart';
import '../../core/rail_page.dart';
import '../home/presentation/home_palette.dart';
import '../records/record_store.dart';
import 'app_settings.dart';

/// 설정: sound and records. The vehicle check is the wrench beside 설정 on
/// the home rail.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.records,
  });

  final AppSettings settings;
  final RecordStore records;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 모두 지울까요?'),
        content: const Text('이 차에 저장된 모든 스토리의 팀 기록이 사라지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirmClear'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await records.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록을 모두 지웠어요')));
    }
  }

  @override
  Widget build(BuildContext context) => RailPage(
    title: '설정',
    body: (s, p) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final label = TextStyle(
          fontSize: 32 * s,
          fontWeight: FontWeight.w600,
          color: p.title,
        );
        final hint = TextStyle(fontSize: 26 * s, color: p.description);
        Widget volume(Key key, double value, ValueChanged<double>? onChanged) =>
            Row(
              children: [
                Icon(
                  Icons.volume_down_rounded,
                  size: 44 * s,
                  color: p.description,
                ),
                Expanded(
                  child: Slider(
                    key: key,
                    value: value,
                    divisions: 10,
                    label: '${(value * 100).round()}%',
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 96 * s,
                  child: Text('${(value * 100).round()}%', style: hint),
                ),
              ],
            );
        return ListView(
          children: [
            RailCard(
              s: s,
              palette: p,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('나레이션 음량', style: label),
                  Text('대사를 읽어 주는 목소리 크기예요. 자막은 항상 표시돼요.', style: hint),
                  volume(
                    const Key('narrationVolume'),
                    settings.narrationVolume,
                    (v) => settings.narrationVolume = v,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * s),
            RailCard(
              s: s,
              palette: p,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('배경음악', style: label)),
                      Transform.scale(
                        scale: (s * 2).clamp(1, 2),
                        child: Switch(
                          key: const Key('bgmOn'),
                          value: settings.bgmOn,
                          onChanged: (v) => settings.bgmOn = v,
                        ),
                      ),
                    ],
                  ),
                  volume(
                    const Key('bgmVolume'),
                    settings.bgmVolume,
                    settings.bgmOn ? (v) => settings.bgmVolume = v : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * s),
            RailCard(
              s: s,
              palette: p,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('기록 초기화', style: label),
                        Text('시승차·가족 차처럼 여럿이 쓰는 차에서 기록을 비울 때 써요.', style: hint),
                      ],
                    ),
                  ),
                  SizedBox(width: 24 * s),
                  SizedBox(
                    height: 96 * s,
                    child: OutlinedButton(
                      key: const Key('clearRecords'),
                      onPressed: () => _confirmClear(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.onWarning,
                        side: BorderSide(
                          color: HyundaiColors.activeRed,
                          width: 2 * s,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 36 * s),
                        textStyle: TextStyle(
                          fontSize: 28 * s,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('기록 지우기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
