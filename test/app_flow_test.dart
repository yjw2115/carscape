import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carscape/app.dart';
import 'package:carscape/core/game_session.dart';
import 'package:carscape/features/records/record_store.dart';
import 'package:carscape/features/records/records_page.dart';
import 'package:carscape/features/settings/app_settings.dart';
import 'package:carscape/features/tutorial/domain/tutorial_models.dart';
import 'package:carscape/vehicle/fake_vehicle_service.dart';

PlayRecord rec(String team, int seconds, {String story = 's1', int day = 1}) =>
    PlayRecord(
      storyId: story,
      team: team,
      date: DateTime(2026, 11, day),
      time: Duration(seconds: seconds),
      hints: 0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ranking keeps each team\'s best, fastest first, per story', () {
    final rows = ranking([
      rec('눈사람', 900),
      rec('펭귄', 700),
      rec('눈사람', 600, day: 2),
      rec('북극곰', 600, day: 3),
      rec('펭귄', 100, story: 's2'),
    ], 's1');
    expect(
      [for (final r in rows) '${r.team} ${r.time.inSeconds}'],
      [
        '눈사람 600', // same time as 북극곰 but earlier date
        '북극곰 600',
        '펭귄 700',
      ],
    );
  });

  test('records and settings survive a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    await RecordStore(prefs).add(rec('펭귄', 700));
    AppSettings(prefs)
      ..narrationVolume = 0.3
      ..bgmOn = false;

    final again = await SharedPreferences.getInstance();
    expect(RecordStore(again).all.single.team, '펭귄');
    expect(AppSettings(again).narrationVolume, 0.3);
    expect(AppSettings(again).bgmOn, isFalse);

    await RecordStore(again).clear();
    expect(RecordStore(again).all, isEmpty);
  });

  testWidgets('finished story asks for a team name and saves it', (
    tester,
  ) async {
    final store = RecordStore(await SharedPreferences.getInstance());
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await saveRecordDialog(
              context,
              store,
              's1',
              const TutorialResult(
                playTime: Duration(minutes: 10),
                hintsUsed: 2,
                windowMoves: 0,
              ),
            ),
            child: const Text('finish'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('finish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('teamName')), ' 펭귄 ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveRecord')));
    await tester.pumpAndSettle();
    expect(saved, '펭귄');
    expect(store.all.single.time, const Duration(minutes: 12));
  });

  testWidgets('home rail: tutorial runs the check first; records; settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1682, 1210);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final records = RecordStore(prefs);
    await records.add(rec('펭귄', 700, story: 'story01'));
    final session = GameSession();
    await tester.pumpWidget(
      CarscapeApp(
        vehicle: FakeVehicleService(),
        session: session,
        records: records,
        settings: AppSettings(prefs),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tapRail(String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    await tapRail('튜토리얼');
    expect(
      find.byKey(const Key('startCheck')),
      findsOneWidget,
      reason: 'check first',
    );
    await tapRail('뒤로');
    expect(find.text('차량 점검 완료 · 모든 장치를 쓸 수 있어요'), findsOneWidget);
    await tapRail('홈으로');

    await tapRail('튜토리얼');
    expect(
      find.byKey(const Key('startCheck')),
      findsNothing,
      reason: 'only once',
    );
    await tapRail('홈으로');

    await tapRail('기록·순위');
    expect(find.text('펭귄'), findsOneWidget);
    expect(find.text('11:40'), findsOneWidget);
    await tapRail('홈으로');

    await tapRail('설정');
    await tester.tap(find.byKey(const Key('clearRecords')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmClear')));
    await tester.pumpAndSettle();
    expect(records.all, isEmpty);
    await tapRail('홈으로');

    await tapRail('차량 점검');
    expect(
      find.byKey(const Key('startCheck')),
      findsOneWidget,
      reason: 'wrench',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'vehicle check E2→E5 at real size: retry window, fallback, done',
    (tester) async {
      tester.view.physicalSize = const Size(1682, 1210);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      final session = GameSession();
      await tester.pumpWidget(
        CarscapeApp(
          vehicle: FakeVehicleService(),
          session: session,
          records: RecordStore(prefs),
          settings: AppSettings(prefs),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('차량 점검'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('startCheck')));
      await tester.pumpAndSettle();

      for (var attempt = 1; attempt <= 3; attempt++) {
        await tester.pump(const Duration(seconds: 21));
        expect(find.text('시도 $attempt / 3'), findsOneWidget);
        if (attempt < 3) {
          await tester.tap(find.byKey(const Key('retry')));
          await tester.pump();
        }
      }
      expect(
        find.byKey(const Key('retry')),
        findsNothing,
        reason: 'no 4th try',
      );
      await tester.tap(find.byKey(const Key('without')));
      await tester.pump();
      while (find.bySemanticsLabel('건너뛰기').evaluate().isNotEmpty) {
        await tester.tap(find.bySemanticsLabel('건너뛰기'));
        await tester.pumpAndSettle();
      }
      expect(find.text('점검이 끝났어요'), findsOneWidget);
      expect(find.textContaining('화면 터치로'), findsWidgets);
      await tester.tap(find.byKey(const Key('checkDone')));
      await tester.pumpAndSettle();
      expect(find.text('점검이 끝났어요'), findsNothing, reason: 'back home');
      expect(session.devices.values, contains(DeviceStatus.fallback));
    },
  );
}
