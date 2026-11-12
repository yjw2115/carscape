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
        content: const Text('되돌릴 수 없어요.'),
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
        final amount = TextStyle(fontSize: 28 * s, color: p.title);
        Widget heading(IconData icon, String text) => Row(
          children: [
            Icon(icon, size: 44 * s, color: p.title),
            SizedBox(width: 18 * s),
            Text(text, style: label),
          ],
        );
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
                  child: Text('${(value * 100).round()}%', style: amount),
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
                  heading(Icons.record_voice_over_outlined, '나레이션 음량'),
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
                      Expanded(
                        child: heading(Icons.music_note_outlined, '배경음악'),
                      ),
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
                    child: heading(Icons.delete_outline_rounded, '기록 초기화'),
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
