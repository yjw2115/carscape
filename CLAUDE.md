# Carscape — 차량 방탈출 (현대차 Pleos 차량용 앱 공모전)

이 파일은 Claude Code가 이 레포에서 작업할 때 먼저 읽는 프로젝트 안내서다. 세부 내용은 `docs/`, 화면 시안은 `design/`에 있다.

## 한 줄 소개
차의 실제 버튼(열선, 공조, 창문, 와이퍼 등)을 조작해 퍼즐을 푸는 **차량 안 방탈출 게임**. 앱은 주로 차량 상태를 읽으며, 사용자의 후속 요청에 따라 튜토리얼 조명 단계에서만 독서등을 모두 끄는 초기화를 수행한다. 현재 튜토리얼은 [연결 문서](docs/tutorial-integration.md)의 네 단계 시나리오를 따른다.

## 팀 / 역할
팀 전체가 앱 전체를 만들고, 역할을 나눠 같은 git 레포에서 작업한다.

| 담당 | 영역 | 주요 폴더 |
|---|---|---|
| 윤종욱 | 차량 점검 흐름, 튜토리얼 탭(조작법 익히기), 기록·순위, 설정, 앱 연결(`lib/app.dart`) | `lib/features/entry/`, `guide/`, `records/`, `settings/` |
| 문성훈 | 스토리 진행: 첫 번째 스토리 "얼어붙은 밤"(폴더 이름은 `tutorial/`로 유지)·본편 시나리오의 챕터 진행, 나레이션·대사, 퍼즐 진행 흐름 | `lib/features/tutorial/`, `lib/features/case01/` |
| 하승현 | 홈 화면·공통 UI·배지 등 위 영역에 속하지 않는 부분 | `lib/features/home/`, `lib/features/common/` 등 |

- 작업을 시작하면 **누구의 작업인지 먼저 확인**한다(`git config user.name` 또는 사용자에게 질문). 다른 사람 담당 폴더는 요청 없이 수정하지 않는다.
- 여러 영역이 같이 쓰는 코드(`lib/core/`, `lib/vehicle/`, 테마, 라우팅)는 변경 내용을 PR 설명에 명확히 적고, 장치 ID·점검 결과 상태 같은 공용 규칙은 바꾸기 전에 팀과 합의한다.
- 작업은 기능별 브랜치(`feature/...`)에서 하고 PR로 `main`에 합친다.

## 기술 스택
- Flutter(Dart) 앱 + Android(Kotlin) 브리지 → Pleos Vehicle SDK (`ai.pleos.playground:Vehicle`)
- Maven: `https://nexus-playground.pleos.ai/repository/maven-releases/`
- minSdk 28 필수, JDK 17, 권한은 매니페스트에 `pleos.car.permission.*` 선언
- SDK 연결: MethodChannel(지원 확인 `check…Capabilities`, 현재값 `get…`) + EventChannel(값 구독 `register…`)
- 에뮬레이터: Pleos Connect AVD (Cold boot 필수, RAM 4GB). 팀원 노트북 사양(내장 그래픽 등)에 따라 느릴 수 있음 → **가짜 차량 서비스로 Windows/크롬에서 먼저 개발**한다.

## 반드시 지킬 설계 규칙
1. **화면 크기: 앱 영역 1682×1210 (가로)**. Pleos Connect AVD(2560×1440)에서 왼쪽 주행 화면을 뺀 오른쪽 영역을 잰 값이다(`homeReferenceSize`). 홈과 홈에서 여는 페이지(`lib/core/rail_page.dart`)는 이 기준에서 비율 `s`로 크기를 정한다. 고정 좌표 대신 비율·너비 기준으로 만든다.
2. **누르는 버튼은 화면 왼쪽 아래**(운전석 쪽). 보는 정보는 가운데·오른쪽.
3. **P단에서만 플레이**. 기어가 P가 아니면 즉시 일시정지 화면, 타이머도 정지.
4. **차량 제어는 조명 단계의 독서등 OFF 초기화로 제한한다.** 플레이어가 장치를 조작하고 앱은 상태를 읽는다. 사용자가 승인한 예외는 조명 진입/순서 오류 시 네 독서등을 끄는 기능뿐이다. 액셀 사용 금지. 마지막 단계는 와이퍼와 휠 우회전으로 완료한다.
5. **밖에서 티 나는 장치는 최소화**(와이퍼·비상등·전조등·문 열기·창문). 꼭 써야 하면 안전 문구를 넣는다. 현재 튜토리얼은 네 창문 20%가 해답이며, 사용자의 후속 요청에 따라 0~100% 열림 및 문·트렁크 개방에 따른 추위를 판정한다. 앱이 창문이나 문을 자동 조작하지 않는다.
6. 글자·터치 영역은 줄이지 않는다(터치 44px 이상). 다크 테마.
7. 텍스트는 한국어. 나레이션 대사는 노트 버튼으로 다시 듣기 + 자막 표시.

## 디자인 토큰
- 홈 디자인(하승현) 기준: 현대 CI 색과 라이트/다크 팔레트는 `lib/features/home/presentation/home_palette.dart`(`HomePalette`, `homeTheme`), 글꼴은 Pretendard.
- 홈 왼쪽 버튼 순서는 튜토리얼 → 기능점검(차량 점검) → MY(기록·순위 + 배지, `lib/features/my/`) → 설정.
- 홈에서 여는 페이지(튜토리얼·기능점검·MY·설정)는 `lib/core/rail_page.dart`(`RailPage`, `RailAction`, `RailCard`)로 같은 모양을 쓴다: 왼쪽 버튼 줄(운전석 쪽) + 오른쪽 내용.
- 튜토리얼 스토리 "얼어붙은 밤"은 자체 테마(`tutorial_style.dart`)를 쓴다.

## 진입 + 차량 점검 명세 (담당: 윤종욱, 시안 E1~E5)
흐름: 모드 선택(E1)에서 게임은 바로 시작한다. 차량 점검은 홈의 "기능점검" 버튼으로 따로 연다(`openVehicleCheck`): 점검 안내 → 자동 점검 → 직접 점검 5개(+재시도 창) → 점검 결과 → "완료" 시 연 화면으로 복귀. 점검 전이면 모든 장치를 쓸 수 있다고 본다(`GameSession.canUse`).
- **자동 점검**: 시나리오에 필요한 모든 장치를 `check…Capabilities`로 조용히 확인(사용자 조작 없음).
- **직접 점검**: 자동 점검에서 **지원 확인된 장치 중에서만** 5개를 랜덤 추첨. 스포 방지를 위해 **실제 사용 장치 2~3개 + 미사용 미끼 장치 2~3개**를 섞는다. 다음 항목은 차례가 될 때까지 숨긴다.
- **감지 기준**: 항목 시작 시점 값 대비 변화(또는 목표 상태 도달) → 정상.
- **실패 처리**: 20초 무반응 → 재시도 창, 최대 3회 → "화면 터치로 대신하기" = 해당 장치는 게임에서 **화면 터치 대체**.
- **결과 저장**: 장치별 상태(`supported` / `unsupported` / `verified` / `fallback`)를 게임 전역 상태로 저장해 튜토리얼·본편 퍼즐이 읽는다. 결과 화면에서는 어떤 퍼즐에 쓰이는지 드러내지 않는다.
- 미끼 장치는 흔하고 물리 버튼으로 바로 누를 수 있는 것(내·외기 순환, 뒷유리·사이드미러 열선 등). 무드등처럼 설정 메뉴에서 켜는 장치는 쓰지 않는다.

## 권장 구조
```
lib/
  core/ (theme, routing, game_session 상태)
  vehicle/ (vehicle_service.dart 인터페이스, fake_vehicle_service.dart, pleos_vehicle_service.dart, device_catalog.dart)
  app.dart (홈 버튼·테마 카드 → 각 페이지 연결)
  features/entry/ (차량 점검 E2~E5)  features/guide/ (튜토리얼 탭)  features/records/  features/settings/  ← 윤종욱
  features/tutorial/ (첫 번째 스토리 "얼어붙은 밤")  features/case01/  ← 문성훈
  features/home/  features/common/   ← 하승현
android/app/src/main/kotlin/.../VehicleBridge.kt
```

## 문서 / 시안 위치
- `docs/handoff.md` — 지금까지의 결정 전체 요약(아이디어, 시나리오, 튜토리얼, 점검, 배지, SDK)
- `docs/튜토리얼_얼어붙은밤_화면흐름.xlsx` — 튜토리얼 8화면 흐름 + 장치 점검표
- `design/html/index.html` — 전체 화면 시안(브라우저로 열기), `design/png/` 화면 이미지, `design/Carscape_UI시안.pdf`
- 시안의 `[대괄호]`는 자리표시(시나리오 내용 미정)
