# 차량 입력으로 네 단계 시험하기

작업 브랜치: `feature/tutorial-frozen-night`. main으로 PR을 만들거나 병합하지 않는다.

## 설치와 연결

1. Android Studio의 Device Manager에서 Pleos Connect v2.1 AVD를 Cold Boot로 켠다.
2. 레포 안의 `build/app/outputs/flutter-apk/app-debug.apk`를 에뮬레이터 창에 끌어 설치한다. 이 파일은 빌드 결과이며 Git에는 포함되지 않는다.
3. Carscape를 열고 차량 연결과 P단을 확인한다.
4. PC 터미널에서 포트를 연결한다.

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 forward tcp:8088 tcp:8088
```

5. [Virtual Console](http://127.0.0.1:8088/)을 브라우저에서 열고 계속 켜 둔다. DDS ONLINE인지 확인한다. OFFLINE이면 페이지를 새로고침한다.
6. 「이야기 시작하기」를 누른다. 대사가 끝나면 자동으로 이어진다. 「이어서 해보기」로 빨리 진행해도 된다.

일반 휴대폰 에뮬레이터에는 Pleos Vehicle Service가 없어 실제 입력 모드를 사용할 수 없다. 콘솔은 차량 상태를 시뮬레이션하며, 앱은 Vehicle SDK로 그 상태를 읽는다. 실차의 장치 지원과 반응까지 보장하는 시험은 아니다.

## 1단계: 독서등

`Emulation Controls → Convenience → Reading Lights`를 사용한다.

- 단계 진입 시 앱이 네 독서등을 모두 끈다. 미리 켜져 있어도 수동으로 초기화할 필요가 없다.
- **Rear left → Rear right → Front left → Front right** 순서로 On.
- 순서가 틀리면 앱이 네 등을 모두 Off로 요청하고 실제 Off 상태까지 확인한다. 이후 Rear left부터 다시 시작한다.
- 잘못 켜진 것을 감지한 다음 끄므로 잠깐 켜졌다 꺼질 수 있다. 물리 스위치 자체를 사전에 차단하는 기능은 아니다.
- 초기화 확인 중에는 입력을 세지 않는다. 끄기를 지원하지 않거나 응답하지 않으면 멈추고 오류를 표시한다.
- 이 단계에서만 `CONTROL_CAR_LIGHTS`와 독서등 OFF 명령을 사용한다. 정상 순서의 On은 플레이어가 조작한다.

## 2단계: 글로브박스

`Climate`에서 HVAC Power On, Fan Speed 1 이상, Passenger Target Temperature 26°C 이상으로 맞춘다.

공조 전원·풍량과 온도는 별도 지원 영역을 확인하여 조수석을 우선한다. 실제 글로브박스 열림은 현재 공개 SDK에 없으므로 히터만으로 통과한다.

## 3단계: 가스와 온도

가스 농도와 실내 온도는 실제 가스 센서/실내 온도 측정값이 아닌 **창문·문 상태로 계산하는 게임 게이지**다. 별도의 진행 지시문은 표시하지 않는다. 게이지에 초록 안전 범위를 표시한다.

`Convenience → Window Position`에서 네 창문을 조작한다. **정답은 네 창문 각각 20%, 네 차 문과 뒷 트렁크 닫힘**이다. 수치가 안정되면 자동 통과한다.

설계 상수: x = 1°C, y = 가스 농도 25%p. 초기 온도 20°C, 가스 100%. 창문 사이 수치는 선형 보간한다.

| 창문 한 개 열림 | 온도 하락 | 가스 감소 기여 |
|---|---:|---:|
| 20% | 1x | 1y |
| 40% | 5x | 2y |
| 60% | 10x | 3y |
| 80% | 15x | 4y |
| 100% | 20x | 5y |

- 전체 온도 하락은 4x 이하, 가스 감소 기여는 4y 이상이어야 한다.
- 이 수치 조합에서는 네 창문 20%가 해답이다. 네 창문 20~40%가 모두 정답인 것은 아니다.
- 창문을 조작하면 가스는 개방률에 대응하는 목표 농도로 서서히 바뀐다. 한 창문을 오래 열어 두는 방식으로 네 창문 조건을 대신할 수 없다.
- 앞 트렁크(프렁크)는 온도, 가스, 통과 조건에 영향을 주지 않는다.
- 차 문이나 뒷 트렁크를 열면 가스가 즉시 0%로 내려가고, 열린 곳마다 목표 온도가 10°C 낮아진다. 열어 둔 상태에서는 통과할 수 없다. 닫으면 창문 개방률에 따라 가스와 온도가 다시 변한다.
- 창문을 크게 열거나 차 문이나 뒷 트렁크를 열면 화면에 얼음이 서서히 쌓인다. 닫거나 조절하면 온도와 화면이 회복된다. 실패로 게임을 종료하지 않는다.
- 처음 추위 한도를 넘겼을 때만 「추워서 손이 안 움직여...」를 배경 대사로 재생한다. 팝업이나 입력 정지는 없다. 음성 재생이 없는 환경에서도 짧은 자막을 표시한다.
- 각 창문 20%, 가스 0%, 온도 16°C 이상 상태가 1.5초 안정되면 4단계로 이동한다.
- 문·창문 상태를 알 수 없으면 닫힘으로 추정해 통과시키지 않는다.

시험 예: 창문 하나만 100% → 얼어붙음/미완료 → 네 창문 20% + 트렁크 열림 → 미완료 → 트렁크 닫기 → 온도 회복 후 통과.

## 4단계: 눈 너머의 대피소

1. 눈과 성에로 덮인 화면에서 `Windshield Wiper Switch → Front → Low`를 켠다.
2. 실제 앞유리 와이퍼 ON을 감지하면 약 3초 동안 화면이 걷힌다. 도중에 끄면 걷히는 진행도 멈춘다.
3. 시야가 확보되면 **오른쪽에 대피소**가 나타난다.
4. 콘솔의 `Steering Angle` 또는 메인 화면 휠을 중앙 0°로 맞춘 뒤 **오른쪽 +30° 이상** 돌린다. 시험할 때 +45°가 편하다.
5. 도착 대사와 시간·힌트 사용 수 결과 화면이 나온다. 안전벨트·악셀 단계는 없다.

대피소가 보이기 전에 오른쪽으로 돌려 둔 값이나 초기 조회 값만으로 자동 완료되지 않는다. 시야 확보 후 새 우회전 입력이 필요하다. P단을 유지한다.

## 임시 시험 버튼

화면 아래 `테스트 · 이전 단계 · 다음 단계 · 처음으로` 버튼을 Android와 브라우저 모두 제공한다. 대사 중이나 센서 오류 화면에서도 사용할 수 있다.

- 이전/다음: 1~4단계 사이 이동. 마지막의 다음은 도착/결과로 이어진다.
- 처음으로: 시간·힌트·대사를 초기화하고 시작 화면으로 돌아간다.
- 단계 이동으로 실제 창문·문·히터·와이퍼·휠을 변경하지 않는다. 1단계로 들어갈 때만 독서등 Off 초기화가 실행된다.
- 이동 버튼을 사용한 결과는 테스트 기록으로 표시한다.
- 배포 시 숨기려면 `--dart-define=TUTORIAL_TEST_NAVIGATION=false`로 빌드한다. 현재 체험 APK에서는 켜져 있다.

## 개발 검증

```powershell
flutter analyze
flutter test
flutter drive --driver=test_driver/vehicle_screenshots.dart --target=integration_test/pleos_vehicle_test.dart -d emulator-5554
```

통합 시험은 실제 AVD 콘솔의 조명·공조·창문·문·트렁크·와이퍼·휠을 바꾸므로 실제 차량에 실행하지 않는다. 종료 시 등·공조·와이퍼 Off, 창문·문·트렁크 닫힘, 휠 중앙, P로 돌린다. 시험 APK와 일반 앱은 다르므로 종료 후 `lib/main.dart` 대상으로 일반 APK를 다시 빌드해 설치한다.

현재 Pleos v2.1의 Extended Controls에는 Car data 메뉴가 없다. 과거 안전벨트 시험 안내는 현재 네 단계에서 사용하지 않는다.

## 이 PC에서 확인한 결과 (2026-11-10)

- 코드 검사 이상 없음, 자동 테스트 25개 통과. 빠른 단계 이동 시 진행 중인 조명 초기화 취소도 포함한다.
- 실제 Pleos SDK와 콘솔로 사전 점등 초기화, 순서 오류 시 네 등 실제 Off 및 콘솔 상태 반영, 정상 조명 순서 통과 확인.
- 실제 히터 → 창문 과다 개방에 따른 결빙 → 트렁크/문 열림 시 미완료 → 네 창문 20%와 닫힘에 따른 회복/통과 확인.
- 실제 와이퍼 → 성에 제거 → 시야 확보 전 회전은 미완료 → 시야 확보 후 우회전 → 결과 화면까지 확인. 단계 이동으로 건너뛰지 않은 시험이다.
- 새 UI 캡처: [가스와 온도](screenshots/carscape-vehicle-gas.png), [결빙](screenshots/carscape-vehicle-freezing.png), [성에](screenshots/carscape-vehicle-frost.png), [대피소](screenshots/carscape-vehicle-shelter.png), [결과](screenshots/carscape-vehicle-result.png).
- 실차 시험은 수행하지 않았다.

## 공식 문서

- [Pleos Virtual Console](https://document.pleos.ai/docs/pleos-only/app-test-guide/virtual-console-guide)
- [SDK 지원 범위 확인](https://document.pleos.ai/en/api-reference/connect-sdk-pleos/Vehicle/check-capability)
