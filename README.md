# Carscape · 얼어붙은 밤

차 안의 사람들이 차량 버튼을 단서로 힘을 합치는 차량 방탈출 앱.
**Android에서는 실제 Pleos Vehicle SDK 입력**, 브라우저에서는 화면 버튼을 사용하는 튜토리얼을 제공한다. Android 앱은 차량 상태를 읽기만 하며 장치를 제어하지 않는다.

## 바로 체험하기 (Windows)

1. 이 폴더의 **`play-tutorial.cmd`를 더블클릭**한다.
2. 첫 실행 준비가 끝나면 브라우저가 열린다. 실행 창은 켜둔다.
3. 「이야기 시작하기」를 누른다. 음량을 켜고 화면의 차량 버튼을 직접 조작한다.
4. 대사는 끝나면 자동으로 이어지며 「다음 대사」로 빨리 진행할 수도 있다.
5. 「나레이션 노트」로 다시 듣기·자막을 볼 수 있다. 힌트 비용 설명은 첫 사용 때만 나오며 이후에는 바로 힌트를 연다.
6. 끝내려면 브라우저와 실행 창을 닫는다. 결과의 「다시 체험하기」 또는 새로고침으로 처음부터 시작한다.

주소는 [로컬 체험 화면](http://127.0.0.1:8765/)이다. 실행 창이 켜져 있을 때만 접속된다. 창 크기를 약 960×600으로 조절하면 차량 화면에 가까운 배치를 볼 수 있다. 창이 작으면 스크롤해 조작한다.

브라우저에서는 차량 없이 화면 버튼으로 체험한다. 안전벨트는 가운데 좌석을 포함한 5석으로 미리 보며, 모두 연결되면 자동으로 대피소에 도착한다. 암전은 앱 영역 안의 연출이다. 「지금 할 일」 안내는 표시하지 않는다.

한국어 음성이 없는 환경에서는 자막으로 진행한다. Chrome에서 소리가 안 나면 Windows의 한국어 음성 설치 여부를 확인하거나 Edge로 같은 주소를 열어볼 수 있다. 현재 목소리는 체험용 TTS이며 최종 성우 녹음은 포함하지 않았다.

## Android / Pleos 에뮬레이터에서 체험하기

1. Android Studio의 **Device Manager**에서 `Pleos_Connect_v2_1`의 메뉴를 열고 **Cold Boot**로 실행한다.
2. 빌드된 `build/app/outputs/flutter-apk/app-debug.apk`를 에뮬레이터 창에 끌어다 놓아 설치한다.
3. 앱 목록에서 **Carscape**를 연다.
4. [Pleos Virtual Console](http://127.0.0.1:8088/)을 PC 브라우저에서 열고 **계속 켜 둔다**. 이 PC에서는 포트 연결을 준비했다. 다시 연결하는 방법은 [차량 입력 시험 안내](docs/tutorial-vehicle-testing.md)를 참고한다.
5. 앱에서 차량 연결과 P단이 확인되면 이야기를 시작한다. **Android 모드에는 퍼즐용 차량 조작 버튼이 없다.** 콘솔이나 차량의 조작에 따른 SDK 상태 변화로 진행한다.

조명은 `Convenience → Reading Lights`의 좌석별 독서등, 히터는 공조 전원 On·풍량 1 이상·조수석 온도 26°C 이상, 창문은 0~50% 위치, 와이퍼는 앞유리의 실제 작동 상태로 판정한다. 글로브박스 열림은 현재 일반 앱 권한으로 읽을 수 없어 **히터만으로 통과**한다.

벨트는 차량이 보고한 모든 좌석이 필요하다. 이 AVD에서는 **운전석·조수석·뒷좌석 좌우·가운데의 5석**을 감지했다. 현재 Virtual Console에는 벨트 체결 카드가 없다. 경고등/Telltales/착석 센서로 대체 판정하지 않는다. 별도 센서 입력 도구나 실차에서 체결 시험이 필요하다. 자세한 확인 범위와 에뮬레이터 Car data 안내는 [차량 입력 시험 안내](docs/tutorial-vehicle-testing.md)에 있다.

debug APK는 로컬 확인용이며 공모전 제출용 release APK가 아니다. APK가 없는 새 체크아웃에서는 아래 빌드를 먼저 한다. `apk/`에 제출물을 업로드하거나 외부로 게시하는 작업은 하지 않았다.

## 개발 환경

- Flutter 3.47.9 / Dart 3.13.7에서 검증. `pubspec.lock` 포함.
- Android Studio, Android SDK (API 36, NDK 28.2.13676358, Build Tools 36.0.0), JDK 17. minSdk 28.
- Pleos Vehicle SDK 2.3.2. 필요한 읽기 권한만 선언하며 `CONTROL_*` 권한과 차량 상태 쓰기 API는 사용하지 않는다.
- 이 PC에는 `.tools/flutter`와 `.tools/jdk-17.0.21+9`를 로컬 설치했다. `.tools`와 빌드 결과는 Git에서 제외된다.
- Android Studio에서 Flutter 플러그인을 설치하고 Flutter SDK 경로를 이 폴더의 `.tools/flutter`로 지정할 수 있다.
- 팀원이 새로 받으면 [Flutter 설치 안내](https://docs.flutter.dev/install/manual)에 따라 SDK를 설치하고 PATH에 추가한다. 실행 파일은 레포 안의 SDK를 먼저, 다음으로 PATH의 Flutter를 찾는다.

```powershell
# 이 PC의 로컬 SDK로 실행
.\.tools\flutter\bin\flutter.bat run -d chrome

# 검사
.\.tools\flutter\bin\flutter.bat analyze
.\.tools\flutter\bin\flutter.bat test

# 다른 PC에서는 PATH의 flutter로 같은 명령을 실행
flutter pub get
flutter run -d chrome
flutter build apk --debug --target-platform android-x64,android-arm64
```

공모전 [공식 개발 환경](https://appdevchallenge.auto-hmg.io/guide/development)과 [제출 안내](https://appdevchallenge.auto-hmg.io/guide/submission)도 참고한다. 현재 APK는 체험용이며 실차 지원/최종 제출 완료를 뜻하지 않는다.

## 담당 범위와 팀 연결

`lib/features/tutorial/`에 시나리오·대사·퍼즐·결과를 모았다. 홈/모드 선택/차량 점검/본편/공통 배지 기능은 다른 담당자의 영역이다. `lib/main.dart`는 테마 선택 이후 화면을 단독 실행하는 최소 진입점이다.

실제 홈에서 진입하는 방법과 차량 입력 연결 계약, 지원 한계는 [튜토리얼 연결 문서](docs/tutorial-integration.md)에 있다. 기존 기획은 [CLAUDE.md](CLAUDE.md), [handoff](docs/handoff.md), [화면 시안](design/html/index.html)을 참고한다.
