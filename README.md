# Carscape

차량의 조명·공조·창문·와이퍼·핸들을 조작해 동승자와 함께 퍼즐을 푸는 차량 방탈출 게임이다.
홈에서 차량 기능점검, 기본 튜토리얼 3문제, 첫 번째 스토리 「얼어붙은 밤」 4단계를 체험할 수 있다. Pleos Connect에서는 Vehicle SDK로 차량 상태를 읽고, 브라우저에서는 가상 차량을 화면 버튼으로 조작한다.

## 공모전 제출 정보

| 항목 | 내용 |
|---|---|
| 앱 이름 | Carscape (첫 번째 스토리 「얼어붙은 밤」) |
| 한 줄 소개 | 차의 실제 버튼(조명·공조·창문·와이퍼·휠)을 조작해 퍼즐을 푸는 차량 안 방탈출 게임 |
| 실행 방법 | [Pleos에서 APK 설치·실행](#android--pleos-에뮬레이터에서-체험하기) · [Windows 브라우저 체험](#바로-체험하기-windows) |
| 테스트 환경 및 설정 | Android Studio Device Manager, Android SDK Platform-Tools(ADB), Pleos Virtual Console. 아래 [설치·연결 절차](#android--pleos-에뮬레이터에서-체험하기) 참고 |
| 에뮬레이터 | Pleos Connect v2.1.0 (Android 14 / API 34, Windows 테스트 AVD는 x86_64) |
| 화면 규격 | 에뮬레이터 전체 2560 × 1440 px, 앱 레이아웃 기준 1682 × 1210 px (가로) |
| APK 위치 | [`apk/Carscape_Carscape_release.apk`](apk/Carscape_Carscape_release.apk) (release, 약 99 MiB) |
| APK 실행 ABI | arm64-v8a, x86_64 |

[개발 환경](#개발-환경)을 준비한 뒤 저장소 루트에서 다음 명령으로 release APK를 빌드할 수 있다. 결과 파일은 `build/app/outputs/flutter-apk/app-release.apk`에 생성된다.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64,android-x64
```

release 빌드는 코드 축소(R8)를 끈다. 켜면 Pleos SDK 내부의 Gson 타입 정보가 지워져 모든 차량 상태 확인이 실패한다(`android/app/build.gradle.kts`).

## 바로 체험하기 (Windows)

1. [Flutter SDK](#개발-환경)를 준비한 뒤 이 폴더의 **`play-tutorial.cmd`를 더블클릭**한다.
2. 첫 실행 준비가 끝나면 브라우저가 열린다. 실행 창은 켜둔다.
3. 홈에서 「튜토리얼」 또는 「얼어붙은 밤」의 「시작하기」를 누른다. 화면의 차량 버튼으로 퍼즐을 진행한다.
4. 대사는 끝나면 자동으로 이어진다. 화면에 표시되는 진행 버튼으로 먼저 넘어갈 수도 있다.
5. 「나레이션/힌트」에서 대사를 다시 듣거나 자막을 읽을 수 있다. 힌트를 열면 최종 기록에 1분이 더해진다.
6. 끝내려면 브라우저와 실행 창을 닫는다.

주소는 [로컬 체험 화면](http://127.0.0.1:8765/)이다. 실행 창이 켜져 있을 때만 접속된다. 창 크기를 약 960×600으로 조절하면 차량 화면에 가까운 배치를 볼 수 있다. 창이 작으면 스크롤해 조작한다.

「얼어붙은 밤」의 브라우저 나레이션은 앱에 포함된 한국어 음성 파일을 재생한다. 대사는 자막으로도 확인할 수 있다.

## Android / Pleos 에뮬레이터에서 체험하기

1. Android Studio의 **Device Manager**에서 **Pleos Connect v2.1.0** AVD를 실행한다. 스냅샷 없이 부팅하려면 **Cold Boot**를 선택한다. 차량 입력 시험에는 Pleos Vehicle Service가 포함된 AVD가 필요하다.
2. 저장소의 [`apk/Carscape_Carscape_release.apk`](apk/Carscape_Carscape_release.apk)를 에뮬레이터 창에 끌어다 놓아 설치한다. 아래 명령 중 `install`을 사용해도 된다.
3. PC의 PowerShell에서 저장소 루트로 이동해 ADB 포트를 연결한다. `devices` 출력에 표시된 Pleos AVD의 ID가 다르면 `emulator-5554`를 해당 ID로 바꾼다.

   ```powershell
   $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
   $pleosEmulator = 'emulator-5554'
   & $adb devices -l
   & $adb -s $pleosEmulator forward tcp:8088 tcp:8088
   # APK를 끌어다 놓았다면 아래 설치 명령은 생략한다.
   & $adb -s $pleosEmulator install -r 'apk/Carscape_Carscape_release.apk'
   ```

4. PC 브라우저에서 [Pleos Connect Virtual Console](http://127.0.0.1:8088/)을 연다. **DDS ONLINE**을 확인하고 콘솔을 켜 둔다. `Emulation Controls`의 `Gear Selection`을 **P**로 설정한다.
5. 에뮬레이터의 앱 목록에서 **Carscape**를 연다. 홈에서 「기능점검」으로 차량 장치 지원을 확인하거나 「튜토리얼」을 시작한다. 「얼어붙은 밤」을 시험하려면 홈의 스토리 카드에서 「시작하기」를 누른 뒤 시작 화면에서도 「시작하기」를 누른다. 콘솔의 장치를 조작하면 앱이 Vehicle SDK 상태 변화를 읽는다. 플레이는 P단에서 진행한다.

SDK 연결이 확인되면 튜토리얼에서 `Air Recirculation → Recirculate`, `Defroster → Rear → On`, `Air Conditioning → On`을 차례로 시험할 수 있다. 해당 장치가 이미 켜져 있으면 껐다가 다시 켜 입력 변화를 준다.

「얼어붙은 밤」에서 `Reading Lights`는 **Rear left → Rear right → Front left → Front right** 순서로 켠다. 앱이 스토리 시작과 순서 오류 시 네 등을 끄고 Off 상태를 확인한다. 난방 단계에서는 공조 전원 On·풍량 1 이상·조수석 목표 온도 26°C 이상을 새로 맞춘다.

가스 단계에서는 `Window Position`으로 **네 창문을 각각 20%** 열고 **네 문과 뒷 트렁크**를 닫는다. 창문을 크게 열거나 문·뒷 트렁크를 열면 게임 속 온도가 떨어진다. 앞 트렁크의 입력은 무시한다. 가스 농도와 온도는 창문·문 상태로 계산하는 게임 수치다.

마지막 단계에서 `Defroster → Front → On`은 쌓인 눈을 일부 녹인다. `Windshield Wiper Switch → Front → Low`로 시야를 확보한 뒤, `Steering Angle`을 시야가 확보됐을 때의 각도에서 **오른쪽으로 5° 이상** 움직이면 대피소 도착과 결과 화면이 이어진다. 결과 화면에서 홈으로 돌아와 팀 이름으로 기록을 남기고 MY에서 기록과 배지를 확인할 수 있다.

debug 빌드는 **임시 시험용 「이전 단계 / 다음 단계 / 처음으로」 버튼**을 화면 아래에 표시한다. 단계 이동을 사용한 플레이는 기록과 배지에 반영되지 않는다. 제출용 release APK에서는 시험용 버튼을 숨긴다.

`build/app/outputs/flutter-apk/app-debug.apk`는 로컬 확인용이며 Git에 포함되지 않는다. 공모전 제출용은 `apk/` 폴더의 release APK다.

## 개발 환경

- Flutter 3.47.9 / Dart 3.13.7에서 검증. `pubspec.lock` 포함.
- Android Studio, Android SDK (API 36, NDK 28.2.13676358, Build Tools 36.0.0), JDK 17. minSdk 28.
- Pleos Vehicle SDK 2.3.2, TextToSpeech SDK 3.3.1. 앱은 P단에서 독서등을 초기화하고, 기기가 지원하면 스토리 시작 시 공조 전원을 끈다. 「얼어붙은 밤」 나레이션은 Android에서 Pleos 음성 서비스를 사용하며, 서비스를 사용할 수 없거나 앱에서 나레이션 음량을 낮춘 경우 내장 음성으로 재생한다.
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

제출 APK는 Pleos Connect v2.1.0 에뮬레이터 환경에서 확인했다. 공모전 [공식 개발 환경](https://appdevchallenge.auto-hmg.io/guide/development)과 [제출 안내](https://appdevchallenge.auto-hmg.io/guide/submission)도 참고한다.

## 담당 범위와 팀 연결

앱 진입점은 `lib/main.dart`이며, 홈 화면에서 기능점검·튜토리얼·스토리·MY·설정으로 이동한다. `lib/features/guide/`에는 기본 튜토리얼, `lib/features/tutorial/`에는 「얼어붙은 밤」 시나리오·대사·퍼즐·결과를 구현했다.

실제 홈에서 진입하는 방법과 차량 입력 연결 계약, 지원 한계는 [튜토리얼 연결 문서](docs/tutorial-integration.md)에 있다. 기존 기획은 [CLAUDE.md](CLAUDE.md), [handoff](docs/handoff.md), [화면 시안](design/html/index.html)을 참고한다.
