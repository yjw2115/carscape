import 'package:flutter/material.dart';
import '../../core/rail_page.dart';
import '../badges/badge_pages.dart';
import '../badges/progress.dart';
import '../home/domain/escape_theme.dart';
import '../records/record_store.dart';
import '../records/records_page.dart';

/// MY: 기록·순위 on the left half, the badges on the right half. The rail
/// keeps only the way home.
class MyPage extends StatelessWidget {
  const MyPage({
    super.key,
    required this.records,
    required this.progress,
    this.stories = escapeThemes,
    this.highlightStory,
    this.highlightTeam,
  });

  final RecordStore records;
  final Progress progress;
  final List<EscapeTheme> stories;

  /// Marks [highlightTeam]'s record in this story, e.g. right after saving.
  final String? highlightStory;
  final String? highlightTeam;

  @override
  Widget build(BuildContext context) => RailPage(
    title: 'MY',
    body: (s, p) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RecordsPanel(
            store: records,
            s: s,
            palette: p,
            stories: stories,
            highlightStory: highlightStory,
            highlightTeam: highlightTeam,
          ),
        ),
        SizedBox(width: 40 * s),
        Expanded(
          child: BadgeShelf(
            progress: progress,
            s: s,
            palette: p,
            stories: stories,
          ),
        ),
      ],
    ),
  );
}
