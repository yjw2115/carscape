import 'package:flutter/material.dart';
import '../../core/rail_page.dart';
import '../home/domain/escape_theme.dart';
import '../home/presentation/home_palette.dart';
import '../tutorial/domain/tutorial_models.dart';
import '../tutorial/presentation/tutorial_style.dart';
import 'record_store.dart';

String _dateText(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 기록·순위: each team's best record per story.
class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.store,
    this.stories = escapeThemes,
    this.storyId,
    this.highlightTeam,
  });

  final RecordStore store;
  final List<EscapeTheme> stories;
  final String? storyId;

  /// Marks this team's row, e.g. right after saving a record.
  final String? highlightTeam;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late String _story = widget.storyId ?? widget.stories.first.id;

  @override
  Widget build(BuildContext context) {
    final rows = ranking(widget.store.all, _story);
    return RailPage(
      title: '기록·순위',
      rail: (s, p) => [
        for (final story in widget.stories)
          RailAction(
            key: Key('story-${story.id}'),
            s: s,
            palette: p,
            height: 120,
            label: story.title,
            primary: story.id == _story,
            onTap: () => setState(() => _story = story.id),
          ),
      ],
      body: (s, p) {
        final text = TextStyle(fontSize: 30 * s, color: p.title);
        final sub = TextStyle(fontSize: 26 * s, color: p.description);
        if (rows.isEmpty) {
          return Text('아직 기록이 없어요. 스토리를 끝내면 팀 기록이 여기에 올라가요.', style: sub);
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => SizedBox(height: 16 * s),
          itemBuilder: (_, i) {
            final r = rows[i];
            return RailCard(
              s: s,
              palette: p,
              highlight: r.team == widget.highlightTeam,
              child: Row(
                children: [
                  SizedBox(
                    width: 90 * s,
                    child: Text(
                      '${i + 1}',
                      style: text.copyWith(
                        fontSize: 44 * s,
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
                      fontSize: 44 * s,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
