# OpenNotch — App Store 제출 자료 (v0.1.0)

App Store Connect에 붙여 넣을 텍스트와 체크리스트. 스펙 §4.10 산출물.

## 1. 기본 정보
| 항목 | 값 |
|---|---|
| 이름 | OpenNotch |
| 부제(ko) | 노치에서 AirDrop·클립보드·YouTube |
| 부제(en) | AirDrop, clipboard & YouTube in your notch |
| 번들 ID | com.holyshine11.opennotch |
| 카테고리 | 유틸리티 (public.app-category.utilities) |
| 가격 | 무료 |
| 최소 macOS | 14.0 |
| 지원 URL | https://github.com/holyshine11/OpenNotch |
| 개인정보 처리방침 URL | https://holyshine11.github.io/OpenNotch/privacy (GitHub Pages — 아래 5절) |
| 저작권 | © 2026 holyshine11. MIT License. |

키워드(ko, 100자 이내): `노치,AirDrop,클립보드,유튜브,YouTube Music,셸프,파일,드롭,메뉴바,맥북`
키워드(en): `notch,airdrop,clipboard,youtube,youtube music,shelf,file drop,menu bar,macbook`
※ 부제·키워드에 "Dynamic Island" 사용 금지.

## 2. 설명

### ko
OpenNotch는 MacBook 노치를 작은 제어 센터로 바꿔 주는 무료 오픈 소스 앱입니다. 노치를 클릭하거나 파일을 끌어오면 패널이 펼쳐집니다.

• AirDrop — 파일을 노치로 끌어다 놓으면 바로 AirDrop 보내기 창이 열립니다.
• 셸프 — 나중에 쓸 파일을 최대 12개까지 노치에 잠시 보관하고, 다시 꺼내 쓰거나 훑어보기로 확인합니다.
• 클립보드 기록 — 복사한 텍스트·이미지·파일을 기억하고 검색해서 다시 복사합니다.
• YouTube / YouTube Music — 브라우저에서 재생 중인 곡의 제목·아트워크를 보여 주고 재생·일시정지·이전·다음을 제어합니다. (Safari, Chrome, Edge, Arc, Brave, Whale)

노치가 없는 Mac에서는 메뉴 막대 중앙에 가상 노치를 표시합니다. 전역 단축키 ⌃⌥N으로도 열 수 있습니다.

네트워크 통신·분석·계정이 전혀 없습니다. 모든 데이터는 이 Mac에만 저장됩니다. 소스 코드는 GitHub에 MIT 라이선스로 공개되어 있습니다.

### en
OpenNotch turns the MacBook notch into a tiny control center. Click the notch or drag a file onto it and a panel unfolds.

• AirDrop — drop a file on the notch to open the AirDrop sender right away.
• Shelf — park up to 12 files in the notch for later; drag them back out or Quick Look them.
• Clipboard history — remembers text, images and files you copy; search and copy again.
• YouTube / YouTube Music — shows what is playing in your browser with artwork, and offers play/pause/previous/next. (Safari, Chrome, Edge, Arc, Brave, Whale)

On Macs without a notch a virtual notch appears in the middle of the menu bar. The global shortcut ⌃⌥N also opens the panel.

No network, no analytics, no accounts. Everything stays on this Mac. Free and open source (MIT) on GitHub.

## 3. Entitlement Usage Information (심사용, en)
**com.apple.security.temporary-exception.apple-events** — targets: `com.apple.Safari`, `com.google.Chrome`, `com.microsoft.edgemac`, `company.thebrowser.Browser`, `com.brave.Browser`, `com.naver.Whale`.

OpenNotch's media feature shows what is playing in the user's browser and offers play/pause/next/previous. macOS provides no public API for "Now Playing" information, so the app asks the browser through Apple Events for the URL and title of open tabs and, in tabs on youtube.com / music.youtube.com only, runs a small read-only script to get the title, artist, artwork and playback state. Commands are limited to play, pause, next and previous on that tab. The feature is **off by default**; the first Apple Event is sent only after the user presses "Use YouTube controls" and answers the system automation prompt. No Apple Events are sent while the panel is collapsed, and the app never launches a browser. No Finder or System Events targets. No data leaves the Mac.

## 4. Review Notes (심사 노트, en)
- **Where the app lives:** OpenNotch is a menu-bar/notch utility (LSUIElement). On a MacBook with a notch, click the notch. On other Macs a black virtual notch is drawn at the top center of the menu bar — click it, or press ⌃⌥N, or launch the app again to open the panel.
- **YouTube controls (optional):** open youtube.com or music.youtube.com in Safari/Chrome/Edge/Arc/Brave/Whale, then press "Use YouTube controls" in the panel and allow the automation prompt. Full controls additionally require the browser's own switch "Allow JavaScript from Apple Events" (Chrome-family: View › Developer; Safari: Develop menu). Without that switch the app shows only the tab title (read-only mode) — this is expected behaviour, not a bug.
- **Clipboard:** on macOS 15.4+ the first read triggers the system pasteboard prompt; if denied, the panel shows a button to System Settings › Privacy & Security › Pasteboard.
- **AirDrop:** drag any file onto the notch and drop it on the "AirDrop" zone. Requires Wi‑Fi and Bluetooth.
- **Quit:** menu bar icon › Quit OpenNotch, or ⚙︎ in the panel › Quit.
- Demo video: (링크 추가)

## 5. 개인정보 처리방침 URL (GitHub Pages)
1. GitHub 저장소 → Settings → Pages → Source: *Deploy from a branch*, Branch: `main`, Folder: `/docs` 선택.
2. `docs/privacy.md`가 `PRIVACY.md` 내용을 가리키도록 복사(이미 저장소 루트에 `PRIVACY.md` 있음) — 아래 명령:
   `cp PRIVACY.md docs/privacy.md && git add docs/privacy.md`
3. 몇 분 뒤 https://holyshine11.github.io/OpenNotch/privacy 가 열리는지 확인.

## 6. 연령 등급 설문
모든 항목 "없음" → 4+. (폭력·성·도박·의료·무제한 웹 접근·사용자 생성 콘텐츠 모두 없음. 브라우저 탭 제목을 읽지만 웹 콘텐츠를 표시하지 않음.)

## 7. 스크린샷 (2880×1800, 4장)
1. 펼친 패널 — YouTube Music 재생 중 + 셸프에 파일 3개 + 클립보드 칩
2. 파일을 끌어오는 순간의 AirDrop / 셸프 드롭 영역
3. 클립보드 전체 목록 + 검색
4. 노치 없는 화면의 가상 노치(접힌 상태와 펼친 상태를 한 장에)

촬영: 시스템 설정 › 디스플레이에서 2880×1800(또는 "더 많은 공간")으로 바꾸고 `screencapture -x -R x,y,w,h out.png`. 배경화면은 단색 어두운 색 권장.

## 8. 제출 전 체크리스트
- [ ] Release 아카이브: `xcodebuild archive -project OpenNotch.xcodeproj -scheme OpenNotch -configuration Release -archivePath build/OpenNotch.xcarchive`
- [ ] `scripts/review-check.sh <OpenNotch.app>` → entitlements 5개, 사설 심볼 없음
- [ ] App Store Connect에 앱 생성(번들 ID·이름), 위 텍스트 ko/en 입력
- [ ] PrivacyInfo.xcprivacy: 수집 없음, UserDefaults CA92.1 (이미 포함)
- [ ] 개인정보 URL 200 응답 확인
- [ ] 스크린샷 4장 업로드
- [ ] Entitlement Usage Information + Review Notes 붙여 넣기
- [ ] 심사 제출
