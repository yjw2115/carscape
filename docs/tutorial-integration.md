# 얼어붙은 밤 튜토리얼 연결

## 현재 시나리오

사용자가 제시한 시나리오와 후속 수정 요청이 기존 기획보다 우선한다.

1. 암전 → 독서등: Rear left → Rear right → Front left → Front right. 진입/순서 오류 시 실제 등 모두 Off.
2. 따뜻한 조수석 공조 → 글로브박스 수리도구. 공개 SDK에서 열림을 읽을 수 없어 히터만으로 완료.
3. 가스 누출 → 네 창문으로 가스/온도 균형. 현재 해답은 각 창문 20%, 문과 트렁크 닫힘.
4. 눈/성에 → 실제 앞 와이퍼로 시야 확보 → 오른쪽 대피소 → 실제 휠 우회전 → 도착/결과.

기존 창문 회로와 안전벨트 단계는 제거했다. 기어 P가 아니거나 연결이 끊기면 진행·시간·나레이션을 멈춘다.

## 팀 진입 연결

홈/테마 선택에서 `TutorialScreen()`을 연다. `lib/main.dart`는 이를 단독 실행하는 체험용 진입점이다. 홈·차량 점검·공용 장치 ID는 바꾸지 않았다.

Android에서는 자동으로 `PleosTutorialInputSource`를 사용한다. 브라우저나 `previewOnly: true`는 차량 없는 체험용 조작 버튼을 표시한다.

## SDK 연결

Kotlin 브리지: `android/app/src/main/kotlin/io/carscape/carscape/TutorialVehicleBridge.kt`.
공식 Vehicle SDK 2.3.2의 typed API를 사용한다.

- EventChannel `io.carscape/tutorial_vehicle/events`: connection, capabilities, issue, value.
- MethodChannel `io.carscape/tutorial_vehicle`: refresh, diagnostics, setLightPuzzleActive, resetReadingLights.
- 읽기: 독서등 실제 상태, 공조 전원/풍량/온도, 창문 위치, 모든 지원 문·트렁크 위치, 앞 와이퍼 실제 상태, 휠 각도, 기어.
- 쓰기: 조명 단계에서만 네 독서등 OFF. 문·창문·와이퍼·히터·휠·벨트는 제어하지 않는다.
- 조명 OFF 요청 후 실제 상태를 재조회한다. 실패/미확인일 때 논리 상태만 초기화해 성공 처리하지 않는다.
- 알 수 없는 문/창문 값은 닫힘으로 바꾸지 않는다.
- 지원 범위/차종별 창문 원시 범위를 확인하고 0~100% 열림으로 정규화한다.
- 초기 조회는 사용자의 새 조작으로 세지 않는다. 현재 상태는 대사/일시정지 중에도 계속 기록한다.
- 게임 입력은 오른쪽 양수. SDK 2.3.2/현재 Pleos v2.1 AVD는 콘솔의 시계 방향 +45°를 -45°로 보고해 브리지에서 부호를 정규화한다. 대피소 표시 후 중앙에서 새로 오른쪽 30° 이상 돌려야 완료한다. 실차 방향과 권한은 별도 확인이 필요하다.

기존 공용 소스 대신 별도 입력 소스를 주입하려면 `TutorialInputSource`의 관찰 스트림과 refresh, setLightPuzzleActive, resetReadingLights를 구현한다. 조명 제어는 사용자 후속 요청으로 허용된 예외이며 다른 장치 제어로 확대하지 않는다.

## 계산과 화면

가스와 온도는 게임 수치이며 실제 가스 농도나 실내 온도 측정값으로 해석하지 않는다. 상수는 `TutorialController.windowColdCost`, targetGas, targetTemperature에 모았다. x=1°C, y=25%p, 온도 20°C에서 시작, 하한 16°C. 열림에 따른 목표 수치로 서서히 바뀌며 1.5초 안정 후 완료한다.

매 플레이 첫 추위 반응만 배경 음성으로 재생한다. 별도 팝업/정지 없음. 성에 텍스처는 코드로 그려 투명도를 조절하며, 와이퍼에 따라 시야가 걷힌다. 참고 사진 자체를 앱 이미지로 배포하지 않는다.

힌트 비용 설명은 첫 사용 한 번만 표시한다. 이후도 힌트는 1회당 1분이 추가된다. 지금 할 일 패널은 없다.

## 임시 개발 이동

이전 단계/다음 단계/처음으로 버튼은 기본으로 표시한다. 최종 체험에서 숨기려면 빌드 시 `--dart-define=TUTORIAL_TEST_NAVIGATION=false`를 지정한다.

`TutorialResult.usedTestNavigation`이 true이면 단계 이동을 사용한 기록이다. 팀의 기록 저장/배지 연결에서 구분할 수 있다. 처음으로는 새 플레이를 시작한다.

차량 없이 기본 흐름은 브라우저에서 체험하고, 실제 SDK 연결은 Pleos AVD 통합 시험으로 확인한다. 시험 순서와 수치표는 [차량 시험 안내](tutorial-vehicle-testing.md)를 참고한다.
