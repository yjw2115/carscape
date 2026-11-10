# 튜토리얼 연결 안내

문성훈 담당. `feature/tutorial-frozen-night`. main에 병합된 `aa5830f`에서 이어서 작업했다. 사용자 최신 시나리오가 기존 handoff/xlsx보다 우선한다.

## 진입과 실행 모드

`TutorialScreen()`은 Android에서 `PleosTutorialInputSource`를 생성해 실제 SDK 입력을 사용한다. 차량의 연결과 P단 확인 전에는 시작을 막는다. Android에 퍼즐용 차량 조작 버튼은 표시하지 않는다. Web에서는 차량 없이 체험하도록 화면 버튼을 유지한다. 테스트나 명시적 미리보기에는 `previewOnly: true`를 전달한다.

```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => TutorialScreen(
    onFinished: (result) => Navigator.of(context).pop(),
  ),
));
```

별도 차량 레이어가 완성되면 `inputSource:`로 `TutorialInputSource`를 주입할 수 있다. 공유 장치 ID/점검 결과 타입을 새로 정의하지 않았으며 `lib/core`, `lib/vehicle`, 다른 팀원의 기능 폴더는 변경하지 않았다.

## SDK와 네이티브 경계

- `TutorialVehicleBridge.kt`: Vehicle SDK 2.3.2 세션, 기능별 Capabilities, 현재값 읽기, 조명/창문/와이퍼/벨트/기어의 변화 구독, 500ms 현재값 보완 읽기, 구독 해제·세션 release.
- `io.carscape/tutorial_vehicle/events`: 초기 읽기 여부와 함께 상태·Capabilities·오류를 전달하는 EventChannel.
- `io.carscape/tutorial_vehicle`: `refresh`, `diagnostics`만 제공하는 MethodChannel. 차량 쓰기 메서드는 없다.
- `PleosTutorialInputSource`: 네이티브 이벤트를 튜토리얼 타입으로 변환한다.
- 명시된 `pleos.car.permission.CAR_*`, `READ_WINDSHIELD_WIPERS` 읽기 권한만 사용한다. `CONTROL_*`, `PRIVATE_*` 권한 및 차량 `set`/`move` 호출은 없다.
- 현재 SDK의 Gear API는 deprecated지만 공개된 읽기 API이며 `CAR_DRIVE`로 P단을 감지한다. 추후 팀 공용 Android GEAR_SELECTION 읽기 경로로 교체할 수 있다. 실패·null·시간 초과를 P로 가정하지 않는다.

## 시나리오 판정

| 단계 | 실제 입력 및 판정 |
|---|---|
| 정전 | 앱 화면만 암전. 계기판/차량 조명을 앱이 끄지 않음 |
| 전원 | Reading Lights 4석. 뒷좌석 왼쪽 → 뒷좌석 오른쪽 → 조수석 → 운전석의 실제 OFF→ON 변화. 최초 ON 스냅샷은 정답 입력으로 사용하지 않음. 순서 오류 뒤에는 플레이어가 실제 등도 모두 Off로 돌려야 함 |
| 글로브박스 | 공조 전원 On, 풍량 >0, 설정 온도 ≥26°C. 기능별 공조 영역을 따로 확인해 조수석 우선, 필요하면 지원되는 앞좌석 공조. 실제 송풍 온도 측정이 아닌 설정 상태 기반 게임 판정 |
| 글로브박스 열림 | 공개 SDK는 잠금 상태만 제공. Android GLOVE_BOX_DOOR_POS는 특권 권한이 필요하므로 현재는 히터만으로 완료. 잠금 해제를 열림으로 취급하지 않음 |
| 창문 | 초기 읽기는 퍼즐을 열지 않음. 실제 위치 변화로 고장 대사·회로 시작. Capabilities의 원시 범위를 0~100%로 정규화. 0~50%에서 10% 단위 회로 이동. 정답: 뒤 왼쪽20/뒤 오른쪽30/조수석10/운전석20%. 실제 창문을 앱에서 0으로 초기화하지 않음 |
| 와이퍼 | FRONT_WINDSHIELD 실제 WiperState.ON으로 통과. 단순 스위치 선택/Auto 설정만으로 ON을 가정하지 않음 |
| 안전벨트 | Buckled/Occupancy의 지원 좌석 전체 합집합. 비어 있는 자리도 포함. 지원 좌석 중 하나라도 false/null/읽기 실패면 완료하지 않음. 모든 자리 체결 시 악셀 없이 자동 도착 |

벨트 좌석 ID는 `VehicleSeat`의 문자열 영역 ID이며 4개 퍼즐 자리 `CarSeat`와 분리했다. 현재 AVD는 앞좌석 좌우 + 뒷좌석 좌·중·우의 5석이다. 1열 가운데/3열 등도 지원 목록에 있으면 포함한다. 읽을 수 없는 좌석을 제외하거나 자동 체결하지 않는다.

## 상태와 UI

- 모든 단계의 「지금 할 일」과 목표 설명을 삭제했다. 대사, 시각 단서, 사용자가 직접 여는 힌트로 진행한다.
- 힌트 비용 안내는 플레이 중 첫 힌트에만 표시한다. 취소하면 무료이며 다음 클릭에도 첫 사용 설명이 나온다. 첫 힌트를 실제로 열고 나면 챕터가 바뀌어도 설명을 반복하지 않는다. 비용은 매회 +1회/+1분 유지.
- 실제 기어 P 이탈/연결 끊김/중요 센서 읽기 실패/백그라운드/노트·힌트/일시정지에서 시간과 진행을 멈춘다. 물리 상태 캐시는 갱신해 재개 후 오래된 벨트 상태로 완료하지 않는다.
- 초기 읽기/중복 콜백은 조명·창문 조작으로 취급하지 않는다. 상태 조건인 공조·와이퍼·벨트는 대사 종료나 재개 후 현재 관측값으로 평가한다.
- 목소리는 OS 한국어 TTS이며 미지원이면 자막으로 진행한다. `NarrationPlayer`로 녹음 재생 구현을 주입할 수 있다.

## 확인 범위와 한계

`flutter analyze`, `flutter test`, Android/Web 빌드, 실제 AVD/콘솔 연동 테스트를 사용한다. `integration_test/pleos_vehicle_test.dart`는 실제 SDK로 조명→공조→창문→와이퍼→5석 벨트 현재값 읽기를 검증했다. 안전벨트의 양성 체결 입력은 현재 콘솔에 없어 실차/별도 센서 입력 시험이 남아 있다. 5석·9석 모두 체결 시 자동 도착과 가운데 미체결 차단은 단위 테스트로 검증했다.

실제 시험 순서와 콘솔 제한은 [차량 입력 시험 안내](tutorial-vehicle-testing.md)를 참고한다. 공모전 제출·외부 게시·main 병합은 수행하지 않는다.
