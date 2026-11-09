# Carscape — 차량 방탈출 (현대차 Pleos 차량용 앱 공모전)

이 파일은 Claude Code가 이 레포에서 작업할 때 먼저 읽는 프로젝트 안내서다. 세부 내용은 `docs/`, 화면 시안은 `design/`에 있다.

## 한 줄 소개
차의 실제 버튼(열선, 공조, 창문, 와이퍼, 안전벨트 등)을 조작해 퍼즐을 푸는 **차량 안 방탈출 게임**. 앱은 차량 상태를 **읽기만** 하고 차를 직접 제어하지 않는다.

## 팀 / 역할
- 팀 전체가 앱 전체를 만들고, 역할을 나눠 같은 git 레포에서 작업한다.
- 이 레포 작업자(윤종욱)의 담당: **게임 진입 화면(모드 선택) + 차량 점검 흐름**, 이후 게임 종료 화면 연결.
- 다른 사람 담당 폴더는 건드리지 말고, 공통 코드 변경은 PR 설명에 명확히 적는다.

## 기술 스택
- Flutter(Dart) 앱 + Android(Kotlin) 브리지 → Pleos Vehicle SDK (`ai.pleos.playground:Vehicle`)
- Maven: `https://nexus-playground.pleos.ai/repository/maven-releases/`
- minSdk 28 필수, JDK 17, 권한은 매니페스트에 `pleos.car.permission.*` 선언
- SDK 연결: MethodChannel(지원 확인 `check…Capabilities`, 현재값 `get…`) + EventChannel(값 구독 `register…`)
- 에뮬레이터: Pleos Connect AVD (Cold boot 필수, RAM 4GB). 작업자 노트북은 내장 그래픽이라 느릴 수 있음 → **가짜 차량 서비스로 Windows/크롬에서 먼저 개발**한다.

## 반드시 지킬 설계 규칙
1. **화면 크기: 960×600 (가로)**. 플레오스 화면 왼쪽 1/3은 계기판이라 앱은 오른쪽 2/3만 쓴다(정확한 값은 에뮬레이터에서 확인 후 조정). 세로·멀티윈도우 대응을 위해 고정 좌표 대신 너비 기준 반응형으로 만든다.
2. **누르는 버튼은 화면 왼쪽 아래**(운전석 쪽). 보는 정보는 가운데·오른쪽.
3. **P단에서만 플레이**. 기어가 P가 아니면 즉시 일시정지 화면, 타이머도 정지.
4. **차를 제어하지 않는다.** 플레이어가 조작하고 앱은 상태를 읽는다. 액셀 사용 금지(대신 브레이크 유지).
5. **밖에서 티 나는 장치는 최소화**(와이퍼·비상등·전조등·문 열기·창문). 꼭 써야 하면 안전 문구를 넣는다(창문은 0~50% 구간만).
6. 글자·터치 영역은 줄이지 않는다(터치 44px 이상). 다크 테마.
7. 텍스트는 한국어. 나레이션 대사는 노트 버튼으로 다시 듣기 + 자막 표시.

## 디자인 토큰 (시안 기준)
- 배경 `#0B0B0E`, 패널 `#15161B`, 테두리 `#2A2D35`, 본문 `#ECEAE4`, 보조 `#A9A69E`
- 앱 강조(호박) `#E8A33D`, 튜토리얼(얼음) `#8FD3F4`, 전원/따뜻함 `#F2A65A`, 성공 `#9BE0B8`, 경고 `#E07A6A`, 금 배지 `#E8C26A`
- 글꼴: 제목 Noto Serif KR(900), 본문 Noto Sans KR, 숫자·라벨 IBM Plex Mono

## 담당 기능: 진입 + 차량 점검 (시안 E1~E5)
흐름: 모드 선택 → 점검 안내 → 자동 점검 → 직접 점검 5개(+재시도 창) → 점검 결과 → 튜토리얼 소개(T0)
- **자동 점검**: 시나리오에 필요한 모든 장치를 `check…Capabilities`로 조용히 확인(사용자 조작 없음).
- **직접 점검**: 자동 점검에서 **지원 확인된 장치 중에서만** 5개를 랜덤 추첨. 스포 방지를 위해 **실제 사용 장치 2~3개 + 미사용 미끼 장치 2~3개**를 섞는다. 다음 항목은 차례가 될 때까지 숨긴다.
- **감지 기준**: 항목 시작 시점 값 대비 변화(또는 목표 상태 도달) → 정상.
- **실패 처리**: 20초 무반응 → 재시도 창, 최대 3회 → "이 장치 없이 진행" = 해당 장치는 게임에서 **화면 터치 대체**.
- **결과 저장**: 장치별 상태(`supported` / `unsupported` / `verified` / `fallback`)를 게임 전역 상태로 저장해 튜토리얼·본편 퍼즐이 읽는다. 결과 화면에서는 어떤 퍼즐에 쓰이는지 드러내지 않는다.
- 미끼 장치는 흔하고 물리 버튼으로 바로 누를 수 있는 것(내·외기 순환, 뒷유리·사이드미러 열선 등). 무드등처럼 설정 메뉴에서 켜는 장치는 쓰지 않는다.

## 권장 구조
```
lib/
  core/ (theme, routing, game_session 상태)
  vehicle/ (vehicle_service.dart 인터페이스, fake_vehicle_service.dart, pleos_vehicle_service.dart, device_catalog.dart)
  features/entry/ (mode_select, check_intro, check_run, check_retry, check_result, check_planner, check_detector)
  features/tutorial/  features/case01/  features/common/   ← 다른 담당
android/app/src/main/kotlin/.../VehicleBridge.kt
```

## 문서 / 시안 위치
- `docs/handoff.md` — 지금까지의 결정 전체 요약(아이디어, 시나리오, 튜토리얼, 점검, 배지, SDK)
- `docs/튜토리얼_얼어붙은밤_화면흐름.xlsx` — 튜토리얼 8화면 흐름 + 장치 점검표
- `design/html/index.html` — 전체 화면 시안(브라우저로 열기), `design/png/` 화면 이미지, `design/Carscape_UI시안.pdf`
- 시안의 `[대괄호]`는 자리표시(시나리오 내용 미정)
