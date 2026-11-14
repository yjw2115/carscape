import 'dart:async';
import 'package:carscape/features/home/domain/escape_theme.dart';
import 'package:carscape/features/home/integration/parking_status_source.dart';
import 'package:carscape/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestParkingSource implements ParkingStatusSource {
  final controller = StreamController<ParkingState>.broadcast();
  int listens = 0;

  @override
  Stream<ParkingState> watch() {
    listens++;
    return controller.stream;
  }
}

void main() {
  late TestParkingSource parking;
  late List<EscapeTheme> started;
  late List<String> opened;

  setUp(() {
    parking = TestParkingSource();
    started = [];
    opened = [];
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(1682, 1210),
    Brightness brightness = Brightness.dark,
    ParkingState? state = ParkingState.parked,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          parkingSource: parking,
          brightness: brightness,
          onStart: (_, theme) async => started.add(theme),
          onTutorial: (_) async => opened.add('tutorial'),
          onMy: (_) async => opened.add('my'),
          onSettings: (_) async => opened.add('settings'),
          openVehicleCheck: (_) async => opened.add('check'),
        ),
      ),
    );
    if (state != null) parking.controller.add(state);
    await tester.pumpAndSettle();
  }

  Finder startButton() => find.text('시작하기').hitTestable();

  testWidgets('parked car can start the selected theme', (tester) async {
    await pumpHome(tester);

    expect(find.text('얼어붙은 밤'), findsOneWidget);
    expect(startButton(), findsOneWidget);
    await tester.tap(startButton());
    expect(started.single.id, storyFrozenNight);
  });

  testWidgets('gear outside P replaces the start button', (tester) async {
    await pumpHome(tester, state: ParkingState.notParked);

    expect(startButton(), findsNothing);
    expect(find.text('기어를 P단으로 바꾸세요').hitTestable(), findsOneWidget);

    parking.controller.add(ParkingState.parked);
    await tester.pumpAndSettle();
    expect(startButton(), findsOneWidget);
  });

  testWidgets('waits for the gear before allowing a start', (tester) async {
    await pumpHome(tester, state: null);

    expect(startButton(), findsNothing);
    expect(find.text('기어 상태를 확인하고 있어요').hitTestable(), findsOneWidget);
  });

  testWidgets('arrow buttons move through themes and loop', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.bySemanticsLabel('다음 테마'));
    await tester.pumpAndSettle();
    await tester.tap(startButton());
    expect(started.last.id, 'case01');
    // Gear monitoring pauses while the started page is open; the car
    // reports the gear again once it resumes.
    await tester.pump();
    parking.controller.add(ParkingState.parked);

    await tester.tap(find.bySemanticsLabel('이전 테마'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('이전 테마'));
    await tester.pumpAndSettle();
    await tester.tap(startButton());
    expect(started.last.id, 'case03');
  });

  testWidgets('tapping a preview card selects it', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.bySemanticsLabel('시간당 120mm 테마 보기'));
    await tester.pumpAndSettle();
    await tester.tap(startButton());
    expect(started.single.id, 'case01');
  });

  testWidgets('swiping left selects the next theme', (tester) async {
    await pumpHome(tester);

    await tester.fling(find.text('얼어붙은 밤'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    await tester.tap(startButton());
    expect(started.single.id, 'case01');
  });

  testWidgets('chips stay as wide as their labels', (tester) async {
    await pumpHome(tester);

    final chip = find
        .ancestor(of: find.text('1~4인').first, matching: find.byType(Container))
        .first;
    expect(tester.getSize(chip).width, lessThan(200));
  });

  testWidgets('rail buttons open their features', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.bySemanticsLabel('튜토리얼'));
    await tester.tap(find.bySemanticsLabel('기능점검'));
    await tester.tap(find.bySemanticsLabel('MY'));
    await tester.tap(find.bySemanticsLabel('설정'));
    await tester.pumpAndSettle();
    expect(opened, ['tutorial', 'check', 'my', 'settings']);
  });

  testWidgets('vehicle check pauses gear monitoring until it returns', (
    tester,
  ) async {
    final away = Completer<void>();
    tester.view.physicalSize = const Size(1682, 1210);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          parkingSource: parking,
          openVehicleCheck: (_) => away.future,
        ),
      ),
    );
    parking.controller.add(ParkingState.parked);
    await tester.pumpAndSettle();
    expect(parking.controller.hasListener, isTrue);

    await tester.tap(find.bySemanticsLabel('기능점검'));
    await tester.pumpAndSettle();
    expect(parking.controller.hasListener, isFalse);

    away.complete();
    await tester.pumpAndSettle();
    expect(parking.listens, 2);
    expect(parking.controller.hasListener, isTrue);
    expect(find.text('기어 상태를 확인하고 있어요').hitTestable(), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final size in const [
      Size(1682, 1210),
      Size(1280, 800),
      Size(960, 600),
    ]) {
      testWidgets(
        'lays out in ${brightness.name} at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpHome(tester, size: size, brightness: brightness);

          expect(tester.takeException(), isNull);
          expect(startButton(), findsOneWidget);
        },
      );
    }
  }

  group('PleosParkingStatusSource.decode', () {
    test('maps gear values', () {
      expect(
        PleosParkingStatusSource.decode({
          'type': 'value',
          'kind': 'parking',
          'value': true,
        }),
        ParkingState.parked,
      );
      expect(
        PleosParkingStatusSource.decode({
          'type': 'value',
          'kind': 'parking',
          'value': false,
        }),
        ParkingState.notParked,
      );
    });

    test('fails closed on unknown gear or lost connection', () {
      expect(
        PleosParkingStatusSource.decode({
          'type': 'value',
          'kind': 'parking',
          'value': null,
        }),
        ParkingState.checking,
      );
      expect(
        PleosParkingStatusSource.decode({
          'type': 'issue',
          'feature': 'parking',
          'message': 'x',
        }),
        ParkingState.checking,
      );
      expect(
        PleosParkingStatusSource.decode({'type': 'connection', 'value': false}),
        ParkingState.checking,
      );
    });

    test('ignores other vehicle events', () {
      expect(
        PleosParkingStatusSource.decode({
          'type': 'value',
          'kind': 'wiper',
          'value': true,
        }),
        isNull,
      );
      expect(
        PleosParkingStatusSource.decode({'type': 'connection', 'value': true}),
        isNull,
      );
    });
  });
}
