# 노치 앱 전략 브리프 (v0.1 — 조사 완료, 결정 대기)

작성: PM 에이전트 · 2026-08-28 · 근거: 리서처 8명(159개 claim) + 반박 검증 41건(이 Mac에서 샌드박스 테스트 앱을 컴파일해 실측한 항목 포함)

## 0. 한 줄 요약

**노치 오버레이·AirDrop·클립보드·Finder 셸프는 전부 공개 API만으로 샌드박스 안에서 구현 가능하고 MAS 심사 통과 선례가 있다.** 유일한 난제는 **YouTube/YouTube Music 제어**다 — macOS 15.4부터 사설 MediaRemote가 막혔고 macOS 26에도 공개 "지금 재생 중" 읽기 API가 없다. 브라우저에 Apple Events를 보내는 방식이 MAS에서 실제로 출시된 앱들(LookieLoo, NotchNest, NotchBox, Perch)의 방식이며, 사용자가 브라우저 설정 하나를 켜야 한다. 이 기능은 **떼어낼 수 있게** 만들어 심사에서 거절돼도 나머지가 출시되도록 한다.

## 1. 기능별 App Store 실현 가능성 판정

| 기능 | 판정 | 구현 방식 (전부 공개 API) | 필요한 entitlement / 사용자 프롬프트 | 근거·선례 |
|---|---|---|---|---|
| 노치 오버레이 (접힘/펼침, 호버·클릭, 전체화면 위 표시) | **가능** | `NSPanel` (`.borderless, .nonactivatingPanel`), `level = .mainMenu+3`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, 노치 좌표 = `NSScreen.safeAreaInsets.top` + `auxiliaryTopLeftArea/RightArea`. 호버 = `NSTrackingArea(.activeAlways)`, 바깥 클릭 감지 = `NSEvent.addGlobalMonitorForEvents(mouse)` | 권한 프롬프트 **없음** (마우스 전역 모니터는 Accessibility 불필요 — 이 Mac에서 샌드박스 번들로 실측 확인) | NotchDrop(MIT, MAS 출시, 샌드박스), Notch Dock, NotchNest |
| AirDrop | **가능** | 노치에 파일 드롭 → `NSSharingService(named: .sendViaAirDrop).perform(withItems:)`. 드롭된 파일은 프로세스 생존 동안 읽기 권한 자동 부여. 텍스트/URL도 전송 가능 | `app-sandbox` 외 추가 entitlement 없음. 셸프에 보관하려면 `files.bookmarks.app-scope` + security-scoped bookmark | NotchNest·NotchDrop·Notch Dock 모두 이 방식 |
| 클립보드 히스토리 | **가능 (조건부)** | `NSPasteboard.general.changeCount` 0.5~1초 폴링, `org.nspasteboard.ConcealedType/TransientType` 항목 제외, SwiftData 저장. **붙여넣기 = 클립보드에 쓰기 + 사용자가 ⌘V** (Cmd+V 시뮬레이션은 Accessibility 필요 → 2.4.5 거절 사례 있음, v1 제외) | 조건: macOS 15.4+의 "pasteboard privacy" 알림. **이 Mac(26.6.2)에서 샌드박스 테스트 앱으로 실측: 기본값 `.alwaysAllow`, 알림 없음. 개발자 플래그를 켜도 `changeCount`·`types()`는 알림 대상이 아님(내용 읽기만 게이트)** — 하지만 언제든 기본 활성될 수 있으므로 → `accessBehavior == .ask`면 내용 읽기를 멈추고 "시스템 설정 > 개인정보 보호 > 다른 앱에서 붙여넣기 > 허용" 안내 UI 표시 | Maccy·PastePal(MAS) 동일 패턴 |
| Finder 셸프/바로가기 | **가능** | 드롭한 파일 임시 보관(셸프), `NSWorkspace.activateFileViewerSelecting`으로 Finder에서 보기, 즐겨찾기 폴더는 `NSOpenPanel`로 사용자가 선택 → bookmark 영구화, Quick Look 미리보기 | `files.user-selected.read-write`, `files.bookmarks.app-scope`. Downloads 폴더 뷰를 넣으면 `files.downloads.read-write`(정식 entitlement, 허용됨). **시스템 전체 "최근 항목"은 샌드박스에서 불가** → 범위에서 제외 | Apple DTS 답변, NotchDrop |
| YouTube / YouTube Music | **조건부 — 결정 필요 (D1)** | (A) Apple Events → Safari `do JavaScript` / Chrome `execute javascript`로 `navigator.mediaSession.metadata`·`<video>` 상태 읽고 play/pause/next 실행. (B) Safari Web Extension(앱에 번들) + Chrome 확장 → 앱과 통신 | (A): `com.apple.security.temporary-exception.apple-events` [Safari, Chrome, Arc…] + `NSAppleEventsUsageDescription`, TCC 프롬프트 "○○이(가) Safari를 제어하려고 합니다", **브라우저에서 "Apple Events의 JavaScript 허용" 켜기**(Safari는 관리자 암호). (B): entitlement 없음, 프롬프트 없음, Safari 설정에서 확장 켜기 + 사이트 권한 | (A) 선례: LookieLoo(개발자가 직접 확인), NotchNest, NotchBox, Perch — 전부 MAS 출시 중. Apple 문서상 temporary-exception은 "심사관 재량" |

**불가로 확정된 것**: 시스템 전체 Now Playing 읽기(MediaRemote 사설 API·perl 어댑터), 미디어 키 시뮬레이션(CGEvent → Accessibility → 2.4.5 거절), YouTube를 WKWebView에 임베드(4.2/5.2.3 + YouTube 약관), AirDrop **수신**(공개 API 없음), Finder에 Apple Events(명시적 거절 대상), 시스템 최근 항목.

## 2. 노치 윈도우 아키텍처 핵심 결정 (검증 완료)

- 화면마다 `safeAreaInsets.top > 0`이면 실제 노치, 아니면 메뉴바 높이의 **가상 노치**(외장 모니터·노치 없는 Mac 대응 — 심사관이 Mac mini로 테스트할 수 있으므로 필수).
- 윈도우는 항상 **펼친 크기**로 미리 만들고 SwiftUI로 모양만 애니메이션(알파 0 영역은 WindowServer가 클릭을 통과시킴 — 실측 확인). 단, macOS 26.3 RC에 투명 영역 클릭 가로채기 회귀가 있었으므로 방어적으로 접힌 상태에서는 프레임을 노치 크기로 축소하는 옵션 유지.
- 전체화면 앱 위 표시는 `.fullScreenAuxiliary`만으로 충분. SkyLight/CGS 사설 API(boring.notch가 씀)는 **절대 금지**.
- 드래그 접근 감지: 전역 `.leftMouseDragged` 모니터 + `NSPasteboard(name: .drag).changeCount` → 커서가 노치에 닿기 전에 펼침. 파일 URL 읽기는 `performDragOperation`에서만(호버 중 읽으면 샌드박스 확장 소모 → 드롭 실패).
- `NSApplication.didChangeScreenParametersNotification`으로 디스플레이 변경 시 윈도우 재배치.

### 2-1. 이번 조사에서 이 Mac에서 직접 실측·확인한 항목

| 항목 | 결과 |
|---|---|
| 샌드박스 앱의 전역 마우스 모니터 | TCC 프롬프트·기록 없이 동작 (Accessibility 불필요) |
| 투명 윈도우 클릭 통과 | alpha==0 픽셀만 통과, alpha≥1/255는 가로챔 → 접힌 상태에서 그림자 금지 |
| 클립보드 프라이버시 | 26.6.2 기본 `.alwaysAllow`; 플래그 ON 시 `changeCount/types()`는 알림 없음, 내용 읽기만 게이트 |
| Safari 26 "Apple Events의 JavaScript 허용" | 기본 OFF(`AllowJavaScriptFromAppleEvents` 미설정), 개발자 메뉴 필요, 관리자 암호(Apple 문서 기준) |
| Chrome 151 / Edge 145 동일 토글 | 보기 > 개발자 메뉴, 프로필별 설정, 관리자 암호 없음. sdef에 미디어 명령 없음 → JS 필수 |
| Safari sdef | play/pause 명령 없음. URL·제목은 토글 없이 읽기 가능 |
| Xcode 26.6 Safari Extension 템플릿 | 존재, 샌드박스 기본, `SafariWebExtensionHandler` 생성 → App Group으로 앱과 통신 |

## 3. App Store 심사 리스크 Top 10 과 대응

| # | 리스크 | 대응 |
|---|---|---|
| 1 | 2.5.1 사설 API | MediaRemote·SkyLight·CGS 코드 0줄. 의존성도 소스 검토 |
| 2 | 2.4.5 temporary-exception 거절 (YouTube 경로 A) | 기능을 모듈로 격리, 거절 시 entitlement만 빼고 재제출. Review Notes에 대상 번들 ID·목적 명시 |
| 3 | 2.4.5 Accessibility 오남용 | AX API·CGEvent.post 사용 안 함 (자동 붙여넣기 v1 제외) |
| 4 | 4.2 최소 기능 | 4개 기능 + 설정 + 노치 없는 Mac 대응. 심사관 환경(Mac mini)에서 전부 동작해야 함 |
| 5 | 종료/설정 진입 불가 (LSUIElement) | 메뉴바 아이콘 **좌클릭** 메뉴에 설정…(⌘,)·종료(⌘Q), 표준 설정 창, About에 지원 URL |
| 6 | 2.3.1 모호한 심사 노트 | 기능별 재현 절차 + 데모 영상 링크 + 클립보드 프라이버시 설정 안내 |
| 7 | 2.4.5(iii) 자동 실행 | `SMAppService.mainApp` 로그인 항목, 기본 OFF |
| 8 | 5.2.5 상표 | 이름·부제에 "Dynamic Island" 금지, 아이콘·이름에 "YouTube" 금지. "Notch"는 OK |
| 9 | 5.1.1 개인정보 | 개인정보 처리방침 URL 필수(GitHub Pages 한 문단), 라벨 "데이터 수집 안 함", `PrivacyInfo.xcprivacy`(UserDefaults CA92.1, 파일 타임스탬프 C617.1) |
| 10 | 스크린샷/등급/암호화 | 16:10 정확한 해상도(1280×800 등), 연령 등급 설문(2026-01부터 필수), `ITSAppUsesNonExemptEncryption=NO` |

## 4. 에이전트 팀 편성과 도구 배치

| 역할 | 모델·설정 | 담당 | 도구 |
|---|---|---|---|
| **PM** (사용자와 대화하는 유일한 창구) | Fable 5 (이 세션) | 요구 정리, 결정 요청, 워크플로 설계, 최종 검수, 진행 보고 | Workflow 도구, task-observer |
| 아키텍트 / 전략 | Fable 5, effort max | 설계 스펙, 리스크 판정, 구현 계획 작성, 반박 검증 | superpowers `writing-plans`, OMC `architect`·`critic` |
| 구현자 ×N | **Sonnet 5**, effort medium | 파일 단위 구현 (TDD), 각자 별도 worktree | OMC `executor`, ponytail(최소 코드), superpowers `test-driven-development` |
| 리뷰어 | Opus 5 / Fable 5 | 코드 리뷰, 보안 리뷰, "심사 거절 요소" 전용 리뷰 | OMC `code-reviewer`·`security-reviewer`, `/code-review` |
| QA | Sonnet 5 + `computer-use` 스킬 | 실제 앱 실행, 노치 호버/클릭/드롭 시나리오, 외장 모니터 시나리오 | Orca `computer-use`(접근성 트리로 macOS 앱 조작), `xcodebuild test` |
| 스토어 준비 | Haiku 4.5 / Sonnet 5 | 심사 노트, 개인정보 처리방침, ko/en 문자열, 스크린샷 스펙 | OMC `writer` |

- 오케스트레이션은 **Workflow 도구** 한 가지로 통일 (결정적 팬아웃, 결과 캐시, 사용량 예측 가능). GSD·gstack는 이번 프로젝트에선 중복이라 쓰지 않음. 단, gstack `/review`는 PR 단계에서 선택적으로.
- 검증은 항상 **반박 렌즈 2개**(Apple 문서 / 심사 선례)를 붙이되, 한 라운드 검증 대상은 **25건 이하**로 고정 (오늘 226건 팬아웃으로 사용량 한도에 걸린 교훈).
- 토큰 절약: 구현·QA·문서는 Sonnet/Haiku, 설계·리뷰·판정만 Fable/Opus.

## 5. 실행 단계 (각 단계 = 워크플로 1회 + PM 검수)

| 단계 | 산출물 | 완료 기준 |
|---|---|---|
| P0 결정 확정 → 설계 스펙 | `docs/superpowers/specs/…-design.md`, 구현 계획 | 사용자 승인 |
| P1 스켈레톤 | xcodegen 프로젝트, 샌드박스 entitlements, LSUIElement + 메뉴바 메뉴(설정/종료), 노치 윈도우(접힘/펼침·호버·클릭·가상 노치), 설정 창, 로그인 항목, 단위 테스트, 로컬 아카이브 빌드 | 노치 없는 외장 모니터에서도 동작 |
| P2 AirDrop + Finder 셸프 | 드롭 → 셸프 → AirDrop / Finder에서 보기 / Quick Look, bookmark 영구화 | 앱 재시작 후 셸프 유지 |
| P3 클립보드 | 폴링·타입별 저장·비밀 항목 제외·검색·클릭 복사, 프라이버시 게이트 UI | 개발자 플래그 켠 상태에서 알림 없이 동작 |
| P4 YouTube 제어 | D1 결정 경로. 앱은 이 모듈 없이도 완전 동작 | Safari·Chrome에서 재생/일시정지/다음 |
| P5 스토어 준비 | PrivacyInfo, ko/en, 스크린샷, 심사 노트, 개인정보 URL, TestFlight → 제출 | 심사 제출 |

## 6. 사용자가 결정할 항목 (각각 추천 기본값 있음)

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| D1 | YouTube/YT Music 제어 경로 | **(A) Apple Events + 브라우저 JS**: Safari·Chrome·Edge·Arc 한 코드, ~2일, MAS 심사 통과 선례 4개(LookieLoo 등). 사용자 마찰: Chrome은 보기 > 개발자 > "Apple Events의 JavaScript 허용" 1회, **Safari는 개발자 메뉴 켜기 + 같은 토글 + 관리자 암호**. temporary-exception entitlement 필요 → 심사관 재량 거절 가능성 中. 1~2초 폴링. / **(B) Safari Web Extension 번들**: 권한 프롬프트 0, entitlement 0, 이벤트 기반(지연 <300ms), ~6일. **v1은 Safari만**, Chrome/Arc는 v1.1에 Chrome 웹스토어 확장(+~4일, 등록 $5). 미디어 제어 목적의 번들 확장 심사 선례는 미확인(규정상 허용, 4.4). / (C) v1은 재생 정보 표시만(탭 제목, JS 토글 불필요) | 검증 에이전트는 B 추천. **PM 추천: A를 v1**(가장 작고 모든 브라우저 즉시 지원, 최근 선례, 모듈 격리로 거절 시 손실 0) → v2에서 B로 교체해 마찰 제거. Chrome 사용자 비중이 낮고 마찰을 못 참으면 B |
| D2 | 앱 이름 · 번들 ID | "Notch" 포함 가능, "Dynamic Island"·"YouTube" 금지. App Store에 같은 이름이 없는 후보(iTunes Search API 확인): **Notchly, NotchTray, OpenNotch**, NotchBay, TinyNotch, NotchLite (NotchKit·NotchBox·NotchDrop·NotchShelf·NotchNest는 이미 존재) | 후보 중 택1 또는 직접 지정. 번들 ID는 `com.<본인 도메인 또는 이름>.<앱이름>` |
| D3 | 오픈소스 여부·라이선스 | MIT / Apache-2.0 / 비공개 | **MIT** (GPL은 MAS와 충돌) |
| D4 | 최소 macOS 버전 | 13 / 14 / 15 | **14.0** (SwiftData·MenuBarExtra·SMAppService 사용 가능, 경쟁 앱들과 동일선) |
| D5 | 클립보드 자동 붙여넣기(Accessibility) | v1 포함 / 제외 | **제외** (2.4.5 거절 사례) |
| D6 | 펼침 방식 기본값 | 호버 / 클릭 / 둘 다 | **둘 다 구현, 기본값 = 클릭 + 드래그 진입 자동 펼침, 호버는 설정에서 켬(0.3~0.5초 지연·히스테리시스)**. 근거: boring.notch 호버 관련 불만 다수(#388, #746, #764, #1359) |
| D7 | 저장소 | 로컬 git만 / GitHub 공개 | GitHub 공개 (D3=MIT면) — 계정명 필요 |

---

# 부록 A. 경쟁 구도 (리서치 종합)



### 1) 경쟁 앱 일람

| 앱 | 가격 | MAS 여부(샌드박스) | 오픈소스·라이선스 | 미디어 제어 방식 | 특이사항 |
|---|---|---|---|---|---|
| [NotchNest](https://apps.apple.com/us/app/notchnest-dynamic-notch-bar/id6747612321?mt=12) | 무료+IAP (Lifetime $14.99, $2.99/월) | MAS 전용(샌드박스) | 클로즈드 | 앱별 스크립팅 추정. 개발자 리뷰 답변(2026-05-18): "App Store 제한으로 Now Playing 직접 접근 불가" | 본 앱과 기능셋이 가장 유사한 MAS 선례. YouTube Music은 v1.2.4(2026-07)에 추가 |
| [Notch Dock: Control Center](https://apps.apple.com/us/app/notch-dock-control-center/id6763415705?mt=12) | 무료+IAP ($9.99 lifetime / $6.99년) | MAS(샌드박스) | 클로즈드 | 미공개 | 미디어·클립보드·AirDrop·파일 트레이. 쉘프가 파일을 복사+이름변경한다는 리뷰(1.0.2 수정) |
| [LookieLoo](https://apps.apple.com/us/app/lookieloo-rock-your-notch/id6747730721?mt=12) | 무료+Pro $3.99 | MAS(샌드박스) | 클로즈드 | AppleScript → Safari/Chrome/Arc 탭 JS로 YouTube·YouTube Music 제어 (권한 페이지에 "AppleScript" 단일 권한 명시) | macOS 26.0+ 요구. "NotchNook보다 훨씬 부드럽다" 리뷰. 브라우저 YouTube 제어가 MAS 심사를 통과한 증거 |
| [Perch (Dynamic Notch Island)](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12) | 무료+IAP ($3.99/월, lifetime $24.99~49.99) | MAS | 클로즈드 | Spotify/Apple Music + YouTube(v1.5.2) | 233개 평점 4.6. 노치 중앙 업그레이드 배너가 안 사라진다는 1점 리뷰 |
| [NotchBox](https://apps.apple.com/us/app/notchbox-easier-drag-drop/id6737410946?mt=12) | 무료+Pro $4.99 | MAS | 클로즈드 | Apple Music/Spotify + Safari 전용 웹 플레이어 | 구매 독촉·평가 요청 과다 리뷰 |
| [NotchDrop](https://github.com/Lakr233/NotchDrop) | 무료 | MAS(id6529528324, ENABLE_APP_SANDBOX) | **MIT** | 없음 | AirDrop 쉘프 전용. v2.16(2024-11) 이후 스토어 갱신 없음. 본 프로젝트의 최적 코드 참조 |
| [Tuneful](https://github.com/martinfekete10/Tuneful) | $4.99 | MAS 전용 | 구버전만 GitHub, 무라이선스 | Spotify/Apple Music | 음악 전용 |
| [boring.notch](https://github.com/TheBoredTeam/boring.notch) | 무료 | 직접 배포(미서명 DMG/자체 tap) | **GPL-3.0** (복사 금지) | 사설 MediaRemote + `/usr/bin/perl` mediaremote-adapter; YouTube Music은 th-ch 데스크톱 앱 localhost:26538 API | 10.5k★, 마지막 릴리스 v2.7.3(2025-11). 브라우저 YouTube Music 미지원 (#1323 무응답) |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | 무료 | 직접 배포 | GPL-3.0 | 사설 MediaRemote | 노치 있는 MBP 필수 |
| [NotchNook](https://lo.cafe/notchnook) | $25 / $3월, Setapp | 직접 배포 | 클로즈드 | 시스템 Now Playing(사설) | Setapp 1,435리뷰 89%. 권한 반복 요청·외부모니터 이슈 |
| [Alcove](https://tryalcove.com) | $14.99~17 | 직접 배포 | 클로즈드 (releases repo만) | 시스템 Now Playing(사설) | 쉘프·클립보드 없음 |
| [MediaMate](https://wouter01.gumroad.com/l/mediamate) | €6.99 | 직접 배포(Gumroad, 비샌드박스) | 클로즈드 | 사설 MediaRemote | HUD+미디어만. 12.2k 판매, 4.9/5 |
| [MacNotch](https://macnotch.io/compare/best-mac-notch-apps) | $22.99 / $3.99월, Setapp | 직접 배포 | 클로즈드 | 시스템 Now Playing(브라우저 포함) | 클립보드 없음. 비교 블로그는 벤더 작성 |
| [Notchy](https://notchy.dev/) | 무료 | 직접 배포(DMG/tap) | 클로즈드 (오픈소스 아님) | 미공개 | "71 features" |
| Seam / DynamicLake Pro / Droppy / Sapphire / Notchable | $19.90 / $13.99 / €8.55 / 구독 / $9.99~19.99 | 모두 직접 배포 | 클로즈드 (Sapphire는 AGPL-3.0) | 시스템 Now Playing 계열 | Droppy에 "Notchface" 카메라 확장 존재 — 별도 앱 "Notch Face"는 없음 ([검증](https://getdroppy.app)) |
| [PlayNotch](https://github.com/MatteoAdamo82/PlayNotch) | 무료 | 소스 빌드만(ad-hoc, 비샌드박스) | **MIT** | AppleScript → 브라우저 탭 JS (Safari `do JavaScript`, Chromium `execute … javascript`), 1초 폴링 | 0★지만 브라우저 YouTube Music 제어 기법이 코드로 문서화됨 |
| [Notchmeister](https://apps.apple.com/us/app/notchmeister/id1599169747) / [TopNotch](https://topnotch.app/) | 무료 | MAS / 직접 | 클로즈드 | 없음 | 장식·노치 숨김 전용, 기능 경쟁자 아님 |

### 2) 사용자 불만 Top 7 (검증된 순위)

1. **OS 업데이트 후 Now Playing 붕괴** — macOS 15.4에서 mediaremoted가 `now-playing-read-access` 엔타이틀먼트를 강제해 모든 서드파티 앱의 `MRMediaRemoteGetNowPlayingInfo`가 nil 반환 ([boring.notch #417](https://github.com/TheBoredTeam/boring.notch/issues/417), [BTT 포럼](https://community.folivora.ai/t/now-playing-is-no-longer-working-on-macos-15-4/42802)); macOS 26에서 AppleScript Apple Music 소스도 추가 붕괴(#779, wontfix). 공개 API 없음(FB17228659).
2. **"무료" 표기 앱의 페이월·독촉** — Perch "노치 중앙 업그레이드 안내가 안 사라짐", NotchBox "구매 알림 과다·평가 요청 그만" ([Perch 리뷰](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12&see-all=reviews&platform=mac), [NotchBox](https://apps.apple.com/us/app/notchbox-easier-drag-drop/id6737410946?mt=12)). MAS 리뷰에서 가장 빈번.
3. **재생 상태 불일치·앨범아트 누락** — 소스 종료 후 마지막 트랙 잔존(#1237), Chrome YouTube Music 변화 미감지(#1457), 진행바 지연(#1490); NotchNest "앨범아트가 안 나옴", Perch "음악 멈춰야 메뉴가 뜸". MAS 앱은 AppleScript 폴링이 원인.
4. **외부 모니터·노치 없는 화면 이상** — 가짜 노치(#1281 not planned, Notch Dock 리뷰), 1px 선(#892), 포커스 디스플레이에만 표시 요청(#1415/#1424/#988), NotchNook 트레이 잘림, NotchNest 클램셸에서 사라짐.
5. **배터리·CPU·랙** — boring.notch #1260(유휴 ~10% CPU, 열림), Perch "노트북 전체가 랙", NotchNook(과거 Product Hunt, 이후 개선).
6. **쉘프가 파일을 이동 대신 복사·이름변경** — Notch Dock 리뷰(.env/코드 파일 리네임, 2026-06). 샌드박스 드롭은 항목 단위 권한만 받으므로 진짜 "이동" 불가 → security-scoped bookmark 참조 보관, 리네임 금지.
7. **권한 혼란** (증거 약함) — NotchNook "이미 허용했는데 계속 요청"(Setapp 2026-08), boring.notch `tccutil reset` 안내(#779), Accessibility의 미디어키 가로채기(#1016). 프롬프트 개수 자체 불만은 없음.

추가: 개발자 무응답(NotchNest), 구매 후 수개월 뒤 동작 중단(NotchBox), Setapp 빌드 지연(NotchNook).

### 3) 무료 앱으로서의 차별화 포지셔닝

- **"업데이트해도 안 깨진다"**: 사설 MediaRemote·perl 셤 없이 Apple Events + 브라우저 JS만 쓰므로 15.4류 붕괴가 구조적으로 없음. 단 macOS 26의 Apple Events 하드닝(`automation.apple-events` 필수, notchmate PR #9)은 우리 경로의 리스크이므로 초기부터 엔타이틀먼트에 반영.
- **"완전 무료·IAP 없음·독촉 없음"**: 불만 2위가 MAS 무료 앱의 페이월. 노치 안에 배너·평가 요청 0회를 명시적 약속으로.
- **"샌드박스·Data Not Collected"**: Accessibility/Screen Recording 요구 없이 AppleScript 단일 권한(LookieLoo 선례)만 — 불만 7 회피.
- **브라우저 YouTube/YouTube Music 제어**: boring.notch·NotchBox(Safari만)가 못 하는 Chrome/Arc 탭 제어를 무료로 — 불만 3의 "YouTube 제어 불가"(NotchBox 리뷰) 공략.
- **쉘프는 참조 보관, 절대 복사·리네임 안 함**, 노치 없는 외부 모니터에서는 표시 안 함 — 불만 4·6을 기본값으로 해결.
---

# 부록 B. MVP 범위와 UX 기본값 (리서치 종합 — D1·D6 결정에 따라 조정)



### 기능별 must / later / never

| 기능 | Must (v1) | Later | Never |
|---|---|---|---|
| **AirDrop** | 파일을 접힌 notch에 드래그 → AirDrop 존 → `NSSharingService(named: .sendViaAirDrop)` + `canPerform` 가드 → 시스템 picker. 다중 파일, Finder/Mail/브라우저 다운로드 소스. 근거: sandboxed MAS 앱(Notch Dock, NotchDrop id6529528324)이 동일 코드로 출시 중 ([docs](https://developer.apple.com/documentation/appkit/nssharingservice/name/sendviaairdrop)). 필수 entitlement: `files.user-selected.read-write` — 없으면 드롭 URL을 읽을 수 없음. | 클립보드 텍스트/URL AirDrop(같은 API가 NSString/NSURL 수용), `NSSharingServicePicker`로 Messages/Mail 공유 | 수신 기능(공개 API 없음, [forums/776563](https://developer.apple.com/forums/thread/776563)), 자체 peer discovery/Bluetooth entitlement([forums/769362](https://developer.apple.com/forums/thread/769362)) |
| **YouTube / YT Music** | 제목·채널·아트워크(`mediaSession.metadata`), play/pause/next/prev, 경과/길이, 아트워크 클릭 시 탭 포커스 — Safari Web Extension 번들로 구현. 근거: MediaRemote는 private+15.4부터 entitlement 필요, WWDC26 Now Playing framework는 publish-only ([wwdc2026/312](https://developer.apple.com/videos/play/wwdc2026/312/), [FB637](https://github.com/feedback-assistant/reports/issues/637)) | Chrome 계열 Web Store 확장, 스크럽 바, 볼륨, Spotify/Apple Music | MediaRemote 등 private framework, 오디오 비주얼라이저(boring.notch 배터리 이슈 [#338](https://github.com/TheBoredTeam/boring.notch/issues/338)), 광고 스킵, 가사 스크래핑 |
| **Clipboard** | 텍스트·URL·이미지(썸네일) 100개, 검색, 클릭=복사(사용자가 ⌘V), ⌃⌥V, `org.nspasteboard.ConcealedType/TransientType` 제외([nspasteboard.org](https://nspasteboard.org/)), Clear 버튼. 근거: 권한 0개 유지 — 자동 붙여넣기(CGEvent ⌘V)는 2025-26 Guideline 2.4.5로 2회 거절 사례([forums/820594](https://developer.apple.com/forums/thread/820594)) | 핀, 자동 붙여넣기(Accessibility 토글 뒤), 스니펫 | 클라우드 업로드, OCR, 무제한 보관 |
| **Finder shelf** | 드롭 파일을 security-scoped bookmark **참조**로 보관(`files.bookmarks.app-scope`), 드래그 아웃=원본 URL, Reveal in Finder, Quick Look, 개별 x + Clear. 근거: Notch Dock이 파일 복사·이름변경해 ".env 깨짐" 리뷰([App Store](https://apps.apple.com/us/app/notch-dock-control-center/id6763415705?mt=12)) | 핀 폴더(Downloads entitlement 또는 NSOpenPanel 1회 승인), 최근 스크린샷 | 원본 이동/이름변경/복사, 시스템 전역 Recents(sandbox 불가 [forums/794441](https://developer.apple.com/forums/thread/794441)), Finder AppleScript([QA1888](https://developer.apple.com/library/archive/qa/qa1888/_index.html)), Full Disk Access |

v1 제외: 캘린더, 날씨, 배터리 애니메이션, HUD 대체, 카메라 미러, 시스템 stats, 테마/폭 슬라이더, Chrome, Spotify — 각각 권한 또는 폴링 루프를 추가함.

### UX 기본값

**접힌 상태**: 물리 notch와 정확히 일치하는 검은 오버레이, 기본은 wing 없음. 상태가 있을 때만 wing: 좌 24pt now-playing 아트워크(정적), 우 shelf 카운트 배지/드래그 호버 아이콘. 주의: 윈도우 서버가 alpha>0 픽셀을 모두 hit-test하므로(0.02도 가로챔, 26.6.2 실측) 접힌 상태에선 notch 외부에 그림자·material을 그리지 말 것 — 메뉴바가 클릭 불가가 됨. `hasShadow=false` 필수.

**Hover vs Click — 기본 Click(+드래그 진입)**. 설정 "열기: Click / Hover(딜레이 0.3–0.5s) / Both". 근거: boring.notch의 hover 관련 불만 — 열리지 않음/떨림/반복 열닫/메뉴바·fullscreen과 충돌 ([#388](https://github.com/TheBoredTeam/boring.notch/issues/388), [#746](https://github.com/TheBoredTeam/boring.notch/issues/746), [#764](https://github.com/TheBoredTeam/boring.notch/issues/764), [#1359](https://github.com/TheBoredTeam/boring.notch/issues/1359)). Hover 모드는 dwell 타이머 + 히스테리시스(확장 영역에서 20pt 이상 300ms 이탈 시 닫힘), 마우스 버튼 down 중엔 열지 않음. 구현은 `NSTrackingArea [.mouseEnteredAndExited, .activeAlways]` — 권한 불필요. 화면 최상단 1pt 행은 메뉴바로 라우팅되므로 패널 frame을 `screen.frame.maxY` 위로 1–2pt 확장(boring.notch [#672/#745/#790] 재현 방지).

**펼친 레이아웃 — 단일 패널, 탭 없음** (~520×180pt). 좌: Now Playing(아트워크 64pt, 제목/채널, 컨트롤, "YouTube Music" 배지) / 우: Shelf 썸네일(빈 상태 "Drop files here · AirDrop") / 하단: 클립보드 최근 5개 칩, "…"로 전체 목록. 바깥 클릭·Esc·조작 후 4s 자동 닫힘. `.nonactivatingPanel`로 앞 앱 포커스 유지. 바깥 클릭 감지는 global `.leftMouseDown` 모니터 + local 모니터 쌍(global은 자기 앱 이벤트를 못 봄) — sandbox·TCC 없이 동작 실측.

**드래그 진입 확장**: 항상 떠 있는 고정 크기 투명 윈도우 안에 notch+32pt 투명(opacity 0.001) 드롭 뷰를 두고 `.onDrop(of:[.fileURL], isTargeted:)` — isTargeted true면 150ms 후 "AirDrop | Shelf" 2존으로 확장(메뉴바 통과 시 깜빡임 방지). 드롭 시 `draggingExited`가 오지 않으므로 `draggingEnded`/drop 완료에서도 접기. hover 중 URL 읽기 금지(sandbox extension 소모, [wadetregaskis](https://wadetregaskis.com/mac-app-sandboxing-interferes-with-drag-drop/)) — `performDragOperation`에서만 읽기. 자체 shelf에서 시작한 드래그엔 확장 안 함.

**키보드 단축키**: ⌃⌥N 패널 토글, ⌃⌥V 클립보드 직행. Carbon `RegisterEventHotKey` — sandbox에서 Accessibility 없이 동작([quicopy](https://www.quicopy.com/blog/macos-sandbox-keyboard-shortcuts)). CGEventTap 금지: 26.6에서 listen-only 마우스 탭도 Input Monitoring 게이트.

**No-notch / 외장 디스플레이**: v1은 `safeAreaInsets.top > 0`인 내장 디스플레이에서만 렌더(화면 단위 판정, `didChangeScreenParametersNotification`에서 재평가). 그 외엔 메뉴바 status item + 단축키로 같은 패널을 띄움. 근거: 외장 화면 가짜 notch·잘못된 디스플레이 활성화 불만([#427](https://github.com/TheBoredTeam/boring.notch/issues/427), [#1176](https://github.com/TheBoredTeam/boring.notch/issues/1176)). fullscreen 앱 위에서는 `.canJoinAllSpaces + .fullScreenAuxiliary`로 표시되며, "fullscreen에서 숨김"은 `visibleFrame.maxY == frame.maxY` 휴리스틱(private CGS 금지).

**온보딩 순서 (TCC 프롬프트 0개)**:
1. "notch를 클릭하세요" — Click/Hover 선택. 권한 없음.
2. "Safari에서 YouTube 확장 켜기" — `SFSafariApplication.showPreferencesForExtension` 버튼 + 건너뛰기. Safari 설정 > 확장 프로그램에서 사용자 활성화 필요.
3. 클립보드 안내 — 권한 없음(`changeCount` 폴링 0.5–1s, 화면 잠금 시 중지). 비밀번호 제외 고지. 향후 pasteboard privacy 강제 시 `accessBehavior == .ask`면 읽기 중단하고 `x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard` 안내([mjtsai](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/)).
4. "로그인 시 실행?" — `SMAppService.mainApp.register`, 사용자 토글만(Guideline 2.4.5 iii).

**설정 항목** (SwiftUI `Settings`, ⌘,): General(열기 방식+hover 딜레이, 로그인 시 실행, fullscreen 숨김, 단축키 레코더, status item 표시) / Media(확장 상태+Safari 열기, notch 아트워크 표시) / Clipboard(활성, 최대 개수, Concealed 제외, Clear) / Shelf(종료 시 비우기, 최대 개수) / About(버전, 소스 링크, 개인정보 페이지).

**Quit/설정 발견성**: LSUIElement지만 메뉴바 status item 기본 표시(숨기려면 경고 후) — 메뉴: Open panel / Settings… / Quit. 펼친 패널에도 기어 아이콘. 재실행 시 `applicationShouldHandleReopen`으로 패널+설정 전면. 종료 시 블로킹 작업 없음. 근거: Notchmeister "종료 안 됨, 재시동 차단" 리뷰([App Store](https://apps.apple.com/us/app/notchmeister/id1599169747?mt=12&see-all=reviews&platform=mac)); 리뷰어가 notch 없는 하드웨어로 테스트할 수 있으므로 Review Notes에 데모 영상 첨부.
---

# 부록 C. 재사용 가능한 오픈소스와 노치 윈도우 구현 레시피



### 1. 참고 저장소 (2026-08-28 기준)

| 저장소 | 라이선스 | MAS 앱에 복사 가능? | 무엇을 가져올지 (파일 단위) | 주의점 |
|---|---|---|---|---|
| [Lakr233/NotchDrop](https://github.com/Lakr233/NotchDrop) | MIT | **예** — 샌드박스+MAS 출시 실적(id6529528324)이 있는 유일한 노치 AirDrop 코드베이스 | `NotchWindow.swift`(레벨/collectionBehavior), `Ext+NSScreen.swift`(노치 기하), `NotchWindowController.swift`, `EventMonitor.swift`/`EventMonitors.swift`(global+local 마우스 모니터), `NotchViewModel+Events.swift`(클릭 in/out 로직), `TrayDrop+View.swift`(opacity 0.001 드롭 뷰 + `.onDrop(isTargeted:)`), `TrayDrop+DropItem.swift`, `Share.swift`/`Share+View.swift`(AirDrop) | 샌드박스는 `.entitlements`가 아니라 `ENABLE_APP_SANDBOX=YES` 빌드 설정으로 켜짐 → 우리 entitlements에 명시적으로 작성. global `.flagsChanged`(Option 키) 모니터는 샌드박스에서 불가 → 복사 금지. `.leftMouseDragged` 모니터는 미사용 dead code. 디버그용 LookInside 의존성 제거. |
| [MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) | MIT | 예 (SPM 또는 vendoring) | `Utility/DynamicNotchPanel.swift`, `Utility/NSScreen+Extensions.swift`(메뉴바 fallback 포함), `Views/NotchShape.swift`, `DynamicNotch.swift`의 "애니메이션을 orderFront 전에 시작" 패턴 | 기본 `.fullScreenAuxiliary` 없음(`panel`이 public이라 추가 가능), 레벨 `.screenSaver`, 윈도우가 화면 절반 크기. MAS 출시 소비자 미확인. 드롭/AirDrop/클립보드 코드 없음. |
| [akalikbergenov/cyclop](https://github.com/akalikbergenov/cyclop) | MIT | 부분 — 미디어 파일 제외 | `Notch/NotchGeometry.swift`(가상 노치 180pt, `CGWindowListCopyWindowInfo`로 상태 아이콘 겹침 회피), `Notch/PointerWatcher.swift`(mouseLocation 폴링 + dwell 히스테리시스), `Services/ClipboardStore.swift`, `Services/ShelfStore.swift`, `UI/ShelfDragSource.swift`, `UI/ShelfPane.swift`, `UI/NotchShape.swift` | `Services/MediaController.swift`, `NowPlayingFeed.swift`, `PlayerBridge.swift`는 `/usr/bin/perl` 주입으로 MediaRemote 접근 → **절대 복사 금지**. 비샌드박스, macOS 15+. |
| [wxtsky/CodeIsland](https://github.com/wxtsky/CodeIsland) | MIT | 윈도우 코드만 | `PanelWindowController.swift`(KeyablePanel, `acceptsFirstMouse` + `mouseDown` override로 non-activating 패널 첫 클릭 전달), `NotchAnimation.swift` | 비샌드박스(automation.apple-events 등). `NotchPanelView.swift` 141KB는 무관. |
| [p0deje/Maccy](https://github.com/p0deje/Maccy) | MIT | 클립보드 코어만 | `Clipboard.swift`(500ms `changeCount` 폴링, ConcealedType/TransientType/AutoGeneratedType·`dyn.`·`com.microsoft.ole.source.` 스킵), `Extensions/NSPasteboard.PasteboardType+Types.swift`, `Models/HistoryItem*.swift` | "직접 붙여넣기"는 Cmd+V CGEvent 합성(Accessibility 필요) → 복사 금지. Sparkle mach-lookup 예외 entitlement 제거. |
| [sindresorhus/LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | MIT | 예 | `Sources/LaunchAtLogin/LaunchAtLogin.swift` (~130줄, `SMAppService.mainApp`) | 사용자 토글로만 켜야 함(Guideline 2.4.5 iii). 직접 `SMAppService.mainApp` 호출로 대체 가능. 구 `LaunchAtLogin`(archived)은 쓰지 말 것. |
| [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) | **GPL-3.0** | **아이디어 참고만** | 참고 대상: `observers/DragDetector.swift`(global `.leftMouseDown/Dragged/Up` + `NSPasteboard(name: .drag).changeCount`로 드래그 접근 감지), `Shelf/Services/QuickShareService.swift`(AirDrop 우선 + Picker fallback), `MediaControllers/YouTube Music Controller/*.swift`(th-ch/youtube-music 로컬 HTTP/WebSocket API 클라이언트) | private SkyLight/CGS/MediaRemote 사용, Sparkle 의존, 비샌드박스 XPC helper. `BoringNotchSkyLightWindow.swift`, `private/CGSSpace.swift`, `NowPlayingController.swift`는 아이디어로도 참고 불가. |
| Ebullioscopic/Atoll, jackson-storm/DynamicNotch | GPL-3.0 | 아이디어 참고만 | 클립보드 히스토리 UX | 복사 금지 |
| MioMioOS/MioIsland | CC BY-NC 4.0 | **불가** | — | 비상업 조건 |
| martinfekete10/Tuneful | 라이선스 없음 | **불가** | — | all rights reserved |
| Alcove ([alcove-releases](https://github.com/henrikruscon/alcove-releases)) | 비공개 | 불가 | — | 바이너리+changelog만 |
| ungive/mediaremote-adapter | BSD-3 | **불가** | — | private framework shim |

MIT/BSD 코드를 복사하면 `THIRD_PARTY_LICENSES` 파일에 원 저작권·라이선스 고지를 유지한다. 어떤 저장소도 `PrivacyInfo.xcprivacy`를 갖고 있지 않으므로 직접 작성(`NSPrivacyAccessedAPICategoryUserDefaults`, 사유 CA92.1; 셸프에 파일 날짜 표시 시 file-timestamp 사유 추가).

### 2. 권장 SwiftPM 의존성

기본은 **0개**. 아래는 필요가 생겼을 때만.

| 패키지 | 라이선스 | 가져오는 조건 |
|---|---|---|
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | MIT | 노치 패널 토글용 글로벌 단축키를 제공할 때. README에 "Fully sandboxed and Mac App Store compatible" 명시(미디어 키 캡처는 샌드박스에서 불가). |
| sindresorhus/Defaults | MIT | 선택. 단순 설정 화면은 `@AppStorage`로 충분. |
| DynamicNotchKit | MIT | 노치 윈도우를 직접 구현하지 않을 때만. `.fullScreenAuxiliary` 추가 필요. |

LaunchAtLogin-Modern은 의존성 대신 `SMAppService.mainApp.register()/unregister()/status` 직접 호출.

### 3. 노치 윈도우 구현 레시피 (검증됨)

**NSPanel 설정** (AppKit에서 직접 생성 — SwiftUI `WindowGroup`은 macOS 15+에서 아래 플래그를 무시)
- `styleMask = [.borderless, .nonactivatingPanel]`
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `isMovable = false`, `isFloatingPanel = true`, `isReleasedWhenClosed = false`
- `canBecomeKey`: 기본 false. 클립보드 검색 등 텍스트 입력이 필요할 때만 명시적 클릭 시 makeKey.
- `acceptsFirstMouse(for:) = true` (non-activating 패널의 첫 클릭 전달)
- `level`: `.statusBar + 8`(NotchDrop) 또는 `.mainMenu + 3`(boring.notch). 펼쳤을 때 Control Center류 패널에 가리지 않도록 `.popUpMenu + 1`로 올리는 옵션.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` — 풀스크린 앱 위에도 표시됨. 잠금화면·Mission Control·Space 전환 애니메이션 중에는 안 보임(수용).
- `orderFrontRegardless()`로 표시.
- **`ignoresMouseEvents`는 절대 대입하지 말 것** (`= false`도 금지). 대입 순간 픽셀 단위 click-through가 영구히 사라짐.

**기하** (`NSScreen`, macOS 12+ public)
- `notchH = screen.safeAreaInsets.top`
- `notchW = screen.frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width`
- `notchFrame = (frame.midX - notchW/2, frame.maxY - notchH, notchW, notchH)`
- 노치 존재 판정: `safeAreaInsets.top > 0 && !auxiliaryTopLeftArea.isEmpty && !auxiliaryTopRightArea.isEmpty` — **화면별**로 판정(기기별 아님). 내장 디스플레이는 `CGDisplayIsBuiltin`.
- 윈도우 frame은 펼친 크기로 고정(NotchDrop: 화면 너비×200pt, boring.notch: 640×190), 상단 = `screen.frame.maxY`, 노치 중심 정렬. 커서를 화면 위로 밀 때 최상단 1pt 행이 메뉴바로 라우팅되는 문제가 있으므로 frame을 `maxY` 위로 1–2pt 연장.
- 접힌 상태에서는 노치 형태(불투명 검정) 외 모든 픽셀 alpha == 0 유지. alpha ≥ 1/255인 픽셀(`.shadow()`, material, 흐린 배경)은 그 아래 메뉴바 클릭을 막는다. [forums/thread/814798](https://developer.apple.com/forums/thread/814798)의 26.3 RC 회귀는 26.3 정식에서 수정, 26.6.2 검증 완료.

**입력 감지 메커니즘과 권한**

| 목적 | 메커니즘 | 권한 |
|---|---|---|
| 호버 진입/이탈 | `NSTrackingArea [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]` 또는 SwiftUI `.onHover`(동일 옵션 설치, 26.6 검증). `.mouseMoved`는 넣지 않음 — 필요 시 enter~exit 사이에만 local/global `.mouseMoved` 모니터 설치(Notchmeister 패턴). | 없음 |
| 노치 클릭 | 콘텐츠 뷰 `mouseDown` / `.onTapGesture`. non-activating이라 포커스 안 뺏음. | 없음 |
| 바깥 클릭으로 닫기 | global `.leftMouseDown/.rightMouseDown` + **local 모니터 쌍**(global은 자기 앱 이벤트를 못 봄). global 콜백에서 `event.window == nil`, 위치는 `NSEvent.mouseLocation`. | 없음 — 샌드박스 26.6.2에서 TCC 프롬프트·기록 없이 검증 |
| 파일 드롭 | `registerForDraggedTypes([.fileURL])`/`NSDraggingDestination` 또는 `.onDrop(of: [.fileURL], isTargeted:)`. `draggingEntered`→펼침, `draggingUpdated`→유지, **`draggingExited`와 `draggingEnded` 둘 다**에서 접기(드롭 성공 시 Exited는 오지 않음). 완전 투명 뷰는 드롭 hit-test 불가 → `opacity(0.001)` + `contentShape`. | `com.apple.security.files.user-selected.read-only`(또는 read-write) 필수 |
| 드래그 접근 시 미리 펼침 | (a) NotchDrop: 노치+32pt 패딩의 거의 투명한 드롭 뷰 — 모니터 불필요. (b) boring.notch/Gladys(MAS): global `.leftMouseDown`에서 `NSPasteboard(name: .drag).changeCount` 스냅샷, `.leftMouseDragged`에서 변경+`.fileURL` 타입 확인 후 `mouseLocation`이 open rect에 들어오면 펼침. drag 보드는 macOS 26 pasteboard privacy 대상 아님. | 없음 |
| 셸프 지속 | security-scoped bookmark + `com.apple.security.files.bookmarks.app-scope` | — |
| AirDrop | `NSSharingService(named: .sendViaAirDrop)`(failable) → `canPerform(withItems:)` 확인 → `perform(withItems: [URL])`. LSUIElement 앱은 호출 전 `NSApp.activate`(안 하면 CGError -606로 조용히 실패). bookmark URL은 `startAccessingSecurityScopedResource` 후 `didShareItems/didFailToShareItems`까지 유지. | 추가 entitlement 없음 |

**노치 없는 Mac/외장 디스플레이 fallback**: 메뉴바 앵커 가상 노치 — 높이 `screen.frame.maxY - screen.visibleFrame.maxY`, 너비 150~300pt(cyclop 180pt), 상단 중앙. 내장 디스플레이만 표시할지 화면마다 윈도우를 만들지는 설정으로.

**화면 변경**: `NSApplication.didChangeScreenParametersNotification`에서 윈도우 재생성/재배치, `NSScreenNumber`+frame 비교로 불필요한 재생성 방지. 풀스크린에서 숨기려면 private API 대신 `visibleFrame.maxY == frame.maxY`(메뉴바 없음) + `NSWorkspace.activeSpaceDidChangeNotification` 휴리스틱.

**SwiftUI 호스팅·애니메이션**: `panel.contentView = NSHostingView(rootView:)`, 호스팅 뷰는 펼친 크기 고정, 노치 형태는 `NotchShape` 경로로 직접 그림. 상태 전환은 `withAnimation(.spring)`/`.interactiveSpring`, **`orderFront` 전에 SwiftUI 애니메이션 시작**(stutter 제거), 숨길 때만 `NSAnimationContext.runAnimationGroup` alpha fade. NSWindow frame 애니메이션 불필요.

### 4. 절대 쓰면 안 되는 것

- **Private API**: SkyLight(`SLS*`, Lakr233/SkyLightWindow — README의 "MAS 가능" 주장은 근거 없음), CGS Spaces(`CGSSpaceCreate`, `CGSCopyManagedDisplaySpaces`, MacroVisionKit), **MediaRemote**(`MRMediaRemoteSendCommand`, mediaremote-adapter perl shim, cyclop의 perl 주입). 모두 [Guideline 2.5.1](https://developer.apple.com/app-store/review/guidelines/) 위반. `@_silgen_name`은 업로드 스캔(ITMS-90338)에서 즉시 탐지되고 `dlsym`은 정책 도박.
- **Temporary exception entitlements** (`com.apple.security.temporary-exception.*`, Sparkle mach-lookup 예외 등).
- **Accessibility / Input Monitoring 의존 기능**: `CGEventTap`(26.6에서는 listen-only 마우스 탭도 Input Monitoring 게이트), global `.keyDown/.keyUp/.flagsChanged` 모니터, Cmd+V CGEvent 합성(Maccy 붙여넣기), `AXIsProcessTrusted` 요구.
- **Sparkle** in MAS 빌드 — App Store가 업데이트를 담당하며 자체 업데이트는 금지. direct-download 빌드가 따로 있을 때만.
- **GPL/CC-NC/무라이선스 코드 복사**: boring.notch, Atoll, jackson-storm/DynamicNotch, MioIsland, Tuneful.
- **`ignoresMouseEvents` 대입**, 접힌 상태의 `hasShadow`/`.shadow()` — 메뉴바 클릭을 막음.
- **SwiftUI `WindowGroup`으로 노치 윈도우 생성** — collectionBehavior 플래그 무시됨.
- 사용자 동의 없는 자동 로그인 실행(2.4.5 iii).