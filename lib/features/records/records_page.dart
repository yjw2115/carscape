import 'package:flutter/material.dart';
import '../home/domain/escape_theme.dart';
import '../home/presentation/home_palette.dart';
import '../tutorial/domain/tutorial_models.dart';
import '../tutorial/presentation/tutorial_style.dart';
import 'record_store.dart';

String _dateText(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 기록·순위 half of the MY page: every story's title followed by its teams'
/// best records, fastest first, in one container.
class RecordsPanel extends StatelessWidget {
  const RecordsPanel({
    super.key,
    required this.store,
    required this.s,
    required this.palette,
    this.stories = escapeThemes,
    this.highlightStory,
    this.highlightTeam,
  });

  final RecordStore store;
  final double s;
  final HomePalette palette;
  final List<EscapeTheme> stories;

  /// Marks [highlightTeam]'s row in this story, e.g. right after saving.
  final String? highlightStory;
  final String? highlightTeam;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final all = store.all;
    return Container(
      padding: EdgeInsets.fromLTRB(36 * s, 32 * s, 36 * s, 0),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(32 * s),
        border: Border.all(color: p.cardBorder, width: 1.5 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 44 * s,
                color: p.selectedBorder,
              ),
              SizedBox(width: 14 * s),
              Text(
                '기록·순위',
                style: TextStyle(
                  fontSize: 40 * s,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
            ],
          ),
          SizedBox(height: 24 * s),
          Divider(height: 1.5 * s, thickness: 1.5 * s, color: p.cardBorder),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 28 * s),
              children: [
                for (final (i, story) in stories.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 36 * s),
                    child: _StoryRecords(
                      s: s,
                      palette: p,
                      title: story.title,
                      rows: ranking(all, story.id),
                      highlightTeam: story.id == highlightStory
                          ? highlightTeam
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryRecords extends StatelessWidget {
  const _StoryRecords({
    required this.s,
    required this.palette,
    required this.title,
    required this.rows,
    required this.highlightTeam,
  });

  final double s;
  final HomePalette palette;
  final String title;
  final List<PlayRecord> rows;
  final String? highlightTeam;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final text = TextStyle(fontSize: 30 * s, color: p.title);
    final sub = TextStyle(fontSize: 24 * s, color: p.description);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 6 * s,
              height: 30 * s,
              decoration: BoxDecoration(
                color: p.selectedBorder,
                borderRadius: BorderRadius.circular(3 * s),
              ),
            ),
            SizedBox(width: 14 * s),
            Expanded(
              child: Text(
                title,
                style: text.copyWith(
                  fontSize: 32 * s,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (rows.isNotEmpty)
              Text('${rows.length}팀', style: sub.copyWith(color: p.title)),
          ],
        ),
        SizedBox(height: 14 * s),
        if (rows.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 22 * s),
            decoration: BoxDecoration(
              color: p.checking,
              borderRadius: BorderRadius.circular(20 * s),
            ),
            child: Text('기록 없음', style: sub.copyWith(fontSize: 26 * s)),
          )
        else
          for (final (i, r) in rows.indexed)
            Container(
              margin: EdgeInsets.only(top: i == 0 ? 0 : 10 * s),
              padding: EdgeInsets.symmetric(
                horizontal: 28 * s,
                vertical: 18 * s,
              ),
              decoration: BoxDecoration(
                color: p.checking,
                borderRadius: BorderRadius.circular(20 * s),
                border: Border.all(
                  color: r.team == highlightTeam
                      ? p.selectedBorder
                      : Colors.transparent,
                  width: 3 * s,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 64 * s,
                    child: Text(
                      '${i + 1}',
                      style: text.copyWith(
                        fontSize: 38 * s,
                        fontWeight: FontWeight.w600,
                        color: i == 0 ? HyundaiColors.gold : p.title,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.team,
                          style: text.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_dateText(r.date)} · 힌트 ${r.hints}개',
                          style: sub,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatTime(r.time),
                    style: text.copyWith(
                      fontSize: 38 * s,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Asks for the team name and date, then saves [result]. Returns the team
/// name, or null when the player skips.
Future<String?> saveRecordDialog(
  BuildContext context,
  RecordStore store,
  String storyId,
  TutorialResult result,
) async {
  final entry = await showDialog<(String, DateTime)>(
    context: context,
    builder: (_) => _SaveRecordDialog(result),
  );
  if (entry == null) return null;
  final (team, date) = entry;
  await store.add(
    PlayRecord(
      storyId: storyId,
      team: team,
      date: date,
      time: result.recordedTime,
      hints: result.hintsUsed,
    ),
  );
  return team;
}

class _SaveRecordDialog extends StatefulWidget {
  const _SaveRecordDialog(this.result);
  final TutorialResult result;

  @override
  State<_SaveRecordDialog> createState() => _SaveRecordDialogState();
}

class _SaveRecordDialogState extends State<_SaveRecordDialog> {
  final _name = TextEditingController();
  var _date = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final team = _name.text.trim();
    return AlertDialog(
      title: const Text('기록 남기기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기록 ${formatTime(widget.result.recordedTime)} · '
            '힌트 ${widget.result.hintsUsed}개',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('teamName'),
            controller: _name,
            autofocus: true,
            maxLength: 12,
            decoration: const InputDecoration(labelText: '팀 이름'),
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Text('날짜 ${_dateText(_date)}'),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: const Text('날짜 바꾸기'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('저장 안 함'),
        ),
        FilledButton(
          key: const Key('saveRecord'),
          onPressed: team.isEmpty
              ? null
              : () => Navigator.pop(context, (team, _date)),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
