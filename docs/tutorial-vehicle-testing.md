# 차량 입력으로 튜토리얼 시험하기

## 설치와 연결

1. Pleos Connect v2.1 AVD를 Cold Boot로 켠다. 일반 휴대폰 AVD는 Vehicle Service가 없어 사용할 수 없다.
2. 레포의 `build/app/outputs/flutter-apk/app-debug.apk`를 에뮬레이터 창에 끌어 설치한다. 기존 앱 위에 설치해도 된다. APK는 Git에 포함되지 않으며 새 체크아웃에서는 먼저 빌드한다.
3. Carscape를 열고 연결 상태가 정상이며 기어가 P인지 확인한다.
4. PC의 터미널에서 아래 명령을 실행한다. Android SDK가 다른 경로에 있으면 그 PC의 adb 경로를 쓴다.

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 forward tcp:8088 tcp:8088
```

5. [Virtual Console](http://127.0.0.1:8088/)을 브라우저에서 열고 켜 둔다. 현재 콘솔은 브라우저 세션이 닫히면 입력 전달이 비활성화된다. 연결된 AVD가 여러 개면 먼저 `adb devices`에서 대상 ID를 확인한다.

콘솔은 차량 상태를 시뮬레이션하고 앱은 Vehicle SDK로 읽는다. 브라우저 미리보기의 게임 버튼을 누르는 것과 다른 경로다. 콘솔 시험은 특정 AVD에서의 검증이며 실차의 모든 장치·권한·값 범위를 보장하지 않는다.

## 단계별 확인 (정답 포함)

| 단계 | 콘솔에서 조작 | 확인할 결과 |
|---|---|---|
| 조명 | `Emulation Controls → Convenience → Reading Lights`. 처음에 4개 모두 Off. Rear left → Rear right → Front right → Front left 순서로 On | 설계도 연결이 1개씩 늘고 다음 대사로 이동 |
| 순서 오류 | 다른 자리부터 On | 연결 표시가 초기화됨. 실제 등은 앱이 끄지 않으므로 모두 Off로 돌린 뒤 재시험 |
| 히터 | `Climate`: HVAC Power On, Fan Speed 1 이상, Target Temperature의 Passenger를 26°C 이상 | 따뜻한 조수석 공조를 감지하면 다음 대사로 이동 |
| 창문 첫 조작 | `Convenience → Window Position`에서 어떤 창문이든 현재 값과 다른 값으로 이동 | 「창문도 먹통이구먼」 이후 회로 등장. 끝 위치에서 같은 값을 다시 보내면 실제 움직임이 없어 감지되지 않음 |
| 창문 회로 | Rear left 20%, Rear right 30%, Front right 10%, Front left 20% | 회로 연결 후 다음 대사. SDK의 차종별 원시 범위를 0~100%로 정규화하며 0~50%만 판정 |
| 와이퍼 | `Convenience → Windshield Wiper Switch → Front → Low` | 스위치 선택이 아니라 실제 와이퍼 ON 상태가 들어오면 다음 대사 |
| 안전벨트 | 아래 별도 안내 | 감지된 **모든 좌석**이 체결되면 악셀 없이 자동 도착 |

공조 전원·풍량은 여러 좌석을 묶어 보고하고 설정 온도는 좌석별로 보고할 수 있다. 이 앱은 각각의 지원 영역을 확인해 조수석 쪽을 우선 선택하고, 없으면 지원되는 앞좌석 공조를 사용한다. A/C를 끄는 것만으로는 히터 작동으로 판정하지 않는다.

글로브박스: Pleos SDK의 공개 API는 잠금 상태를 제공하지만 그것은 열림 상태와 다르다. Android의 `GLOVE_BOX_DOOR_POS`는 서명/특권 권한이 필요한 속성이어서 현재 일반 앱에서는 열림 판정을 사용하지 않는다. 사용자 요청에 따라 히터만으로 완료한다.

## 안전벨트 시험의 현재 한계

이 AVD의 SDK는 `ROW_1_LEFT`, `ROW_1_RIGHT`, `ROW_2_LEFT`, `ROW_2_CENTER`, `ROW_2_RIGHT`의 체결 상태를 제공하며 다섯 자리 모두 읽은 것을 확인했다. 빈 좌석도 제외하지 않는다. 다른 차량은 지원 목록에 따라 가운데·3열 등을 추가하며 4석/5석으로 고정하지 않는다. 읽을 수 없는 좌석을 자동 체결 처리하지 않는다.

하지만 현재 Virtual Console의 48개 카드에는 `SEAT_BELT_BUCKLED` 입력이 없다. Safety의 Telltales는 경고등이며 벨트 버클 센서가 아니다. Seat Occupancy도 착석 센서이므로 대신 사용하면 안 된다.

Android Automotive Emulator는 **Extended Controls → Car data**에서 차량 속성 변경을 지원한다. 해당 AVD에서 이 메뉴와 속성 편집이 제공되는 경우 다음 값을 시험한다. 이 PC의 메뉴를 통한 체결 변경은 아직 검증하지 못했으므로, 지원 메뉴가 없으면 실차 또는 제조사 센서 시뮬레이터가 필요하다.

- 속성: `SEAT_BELT_BUCKLED` (`0x15200B82`, 354421634)
- 영역: 운전석 1, 조수석 4, 뒷좌석 왼쪽 16, 가운데 32, 오른쪽 64
- 값: `true` = 체결, `false` = 미체결
- 4석만 true이고 가운데가 false이면 계속 마지막 화면에 머물러야 한다.
- 마지막 가운데까지 true이면 도착 대사와 결과로 이어져야 한다.

`cmd car_service inject-vhal-event`는 이 Pleos 이미지가 사용자 빌드라 차단되어 사용할 수 없다. 앱에 가짜 체결 버튼을 만들거나 권한을 우회하지 않았다.

## 검증 범위

- `flutter analyze`, `flutter test`: 기본 흐름과 실제 입력 초기값 처리, 순서 오류 후 재시작, 5석/9석의 전체 체결, 가운데 제외 시 미완료, 일시정지 중 벨트 해제, 힌트 비용 설명 첫 회만 표시, 화면 크기별 배치.
- `integration_test/pleos_vehicle_test.dart`: **실제 Android Vehicle SDK + 현재 AVD 콘솔 입력**으로 조명 → 히터 → 네 창문 → 와이퍼 → 전체 벨트 센서 읽기까지 검증. 앱의 가짜 차량 입력을 사용하지 않는다.
- 실제 체결로 마지막 단계가 통과하는 시험은 현재 콘솔 제한으로 미완료다. 모든 체결이 들어왔을 때의 자동 도착 판정은 단위 테스트로 검증했다.

콘솔 브라우저를 열어 둔 상태에서 실행한다. 테스트는 콘솔의 등·공조·창문·와이퍼를 바꾸므로 실제 차량이 아닌 명시된 AVD에서만 실행한다.

```powershell
flutter test integration_test/pleos_vehicle_test.dart -d emulator-5554
```

위 테스트 APK는 테스트 종료 시 제거될 수 있다. 이후 `flutter build apk --debug --target-platform android-x64,android-arm64 -t lib/main.dart`로 일반 설치본을 다시 만들고 설치한다.

## 공식 문서

- [Pleos Virtual Console 사용](https://document.pleos.ai/docs/pleos-only/app-test-guide/virtual-console-guide)
- [Android Automotive Emulator의 Car data](https://developer.android.com/training/cars/testing/emulator)
- [글로브박스 위치 권한](https://developer.android.com/reference/android/car/VehiclePropertyIds#GLOVE_BOX_DOOR_POS)
