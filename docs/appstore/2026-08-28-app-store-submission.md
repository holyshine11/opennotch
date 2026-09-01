# OpenNotch — App Store 제출 자료 (v0.1.0)

App Store Connect에 붙여 넣을 텍스트와 체크리스트. 스펙 §4.10 산출물.

## 1. 기본 정보
| 항목 | 값 |
|---|---|
| 이름 | OpenNotch |
| 부제(ko) | 노치 패널 — 셸프·클립보드·음악 |
| 부제(en) | Notch shelf, clipboard & music |
| 번들 ID | com.holyshine11.opennotch |
| 카테고리 | 유틸리티 (public.app-category.utilities) |
| 가격 | 무료 |
| 최소 macOS | 14.0 |
| 지원 URL | https://github.com/holyshine11/OpenNotch |
| 개인정보 처리방침 URL | https://holyshine11.github.io/opennotch/privacy (GitHub Pages — 아래 5절) |
| 저작권 | © 2026 holyshine11. MIT License. |

키워드(ko, 100자 이내): `노치,클립보드,유튜브,YouTube Music,셸프,파일,드롭,메뉴바,맥북,음악`
키워드(en): `notch,clipboard,youtube,youtube music,shelf,file drop,menu bar,macbook,music,share`
※ 부제·키워드에 "Dynamic Island"·"AirDrop"(Apple 상표, 5.2.5)·"무료/free"(가격 언급, 2.3.7) 사용 금지 — 2026-09-01 리젝 사유. 설명 본문에서는 둘 다 허용(Apple이 가격 언급은 설명에 쓰라고 명시).

## 2. 설명

### ko
정말 무료입니다. 인앱 구매도, 구독도, 잠겨 있는 ‘프로’ 기능도 없습니다 — 음악 제어를 포함한 모든 기능을 처음부터 끝까지 무료로 쓸 수 있습니다. 소스 코드도 공개되어 있습니다.

OpenNotch는 MacBook 노치를 작은 제어 센터로 바꿔 주는 무료 오픈 소스 앱입니다. 노치를 클릭하거나 파일을 끌어오면 패널이 펼쳐집니다.

• AirDrop — 파일을 노치로 끌어다 놓으면 바로 AirDrop 보내기 창이 열립니다.
• 셸프 — 나중에 쓸 파일을 최대 12개까지 노치에 잠시 보관하고, 다시 꺼내 쓰거나 훑어보기로 확인합니다.
• 클립보드 기록 — 복사한 텍스트·이미지·파일을 기억하고 검색해서 다시 복사합니다.
• 음악 — YouTube / YouTube Music / Spotify 웹 플레이어(Safari, Chrome, Edge, Arc, Brave, Whale)와 Apple Music에서 재생 중인 곡의 제목·아트워크를 보여 주고 재생·일시정지·이전·다음·탐색을 제어합니다.

노치가 없는 Mac에서는 메뉴 막대 중앙에 가상 노치를 표시합니다. 전역 단축키 ⌃⌥N으로도 열 수 있습니다.

네트워크 통신·분석·계정이 전혀 없습니다. 모든 데이터는 이 Mac에만 저장됩니다. 소스 코드는 GitHub에 MIT 라이선스로 공개되어 있습니다.

### en
Really free. No in-app purchases, no subscription, no locked “Pro” features — everything, including the music controls, is free from the first launch. The source code is public, too.

OpenNotch turns the MacBook notch into a tiny control center. Click the notch or drag a file onto it and a panel unfolds.

• AirDrop — drop a file on the notch to open the AirDrop sender right away.
• Shelf — park up to 12 files in the notch for later; drag them back out or Quick Look them.
• Clipboard history — remembers text, images and files you copy; search and copy again.
• Music — shows what is playing in YouTube / YouTube Music / Spotify web player (Safari, Chrome, Edge, Arc, Brave, Whale) or Apple Music, with artwork, and offers play/pause/previous/next/seek.

On Macs without a notch a virtual notch appears in the middle of the menu bar. The global shortcut ⌃⌥N also opens the panel.

No network, no analytics, no accounts. Everything stays on this Mac. Free and open source (MIT) on GitHub.

프로모션 텍스트(ko): `정말 무료입니다 — 인앱 구매·구독·잠긴 기능 없음. 음악 제어까지 전부 무료. AirDrop·셸프·클립보드 기록·음악 제어가 노치 한 화면에. 오픈 소스, 네트워크 없음.`
프로모션 텍스트(en): `Really free — no in-app purchases, no subscription, no locked features. Music controls included. AirDrop, file shelf, clipboard history and music in one notch panel.`

## 3. Entitlement Usage Information (심사용, en)
**com.apple.security.temporary-exception.apple-events** — targets: `com.apple.Safari`, `com.google.Chrome`, `com.microsoft.edgemac`, `company.thebrowser.Browser`, `com.brave.Browser`, `com.naver.Whale`.

OpenNotch's media feature shows what is playing in the user's browser and offers play/pause/next/previous/seek. macOS provides no public API for "Now Playing" information, so the app asks the browser through Apple Events for the URL and title of open tabs and, in tabs on youtube.com / music.youtube.com / open.spotify.com only, runs a small read-only script to get the title, artist, artwork and playback state. Commands are limited to play, pause, next, previous and seek on that tab. The first Apple Event is sent only after the user answers the system automation prompt. No Apple Events are sent while the panel is collapsed, and the app opens a browser only when the user presses "Open YouTube in …" in the setup window. No Finder target. No data leaves the Mac.

(2026-09-01: `com.apple.systemevents` 예외는 심사 2.4.5(i)에서 거부되어 빌드 (2)에서 엔타이틀먼트와 SetupAssistant 기능을 함께 제거 — 안내 창의 수동 경로 안내만 남김.)

**com.apple.security.scripting-targets** — `com.apple.Music`: `com.apple.Music.playback`, `com.apple.Music.library.read`.

Used to show the current Apple Music track (name, artist, duration, position, artwork) and to send play/pause/next/previous/seek to the Music app, through the access groups Music.app declares in its scripting definition. Only sent while Music is already running and the panel is open.

## 4. Review Notes (심사 노트, en)
- **Where the app lives:** OpenNotch is a menu-bar/notch utility (LSUIElement). On a MacBook with a notch, click the notch. On other Macs a black virtual notch is drawn at the top center of the menu bar — click it, or press ⌃⌥N, or launch the app again to open the panel.
- **Music controls:** on first launch a "Welcome to OpenNotch" window opens with a live setup checklist; it can be reopened anytime from the menu bar icon › "Music controls setup…" (or the ⚙︎ button in the panel). Each installed browser has a row showing its current status, an "Open YouTube in …" button that opens music.youtube.com in that browser, and the exact menu path for the browser's own switch "Allow JavaScript from Apple Events" (Chrome-family: View › Developer; Safari: Settings › Advanced, then the Developer tab); the row turns green by itself once the switch is on. Without that switch the app shows only the tab title (read-only mode) — this is expected behaviour, not a bug. Apple Music needs no browser switch.
- **Clipboard:** on macOS 15.4+ the first read triggers the system pasteboard prompt; if denied, the panel shows a button to System Settings › Privacy & Security › Pasteboard.
- **AirDrop:** drag any file onto the notch and drop it on the "AirDrop" zone. Requires Wi‑Fi and Bluetooth.
- **Quit:** menu bar icon › Quit OpenNotch, or ⚙︎ in the panel › Quit.
- Demo video: (링크 추가)

## 5. 개인정보 처리방침 URL (GitHub Pages)
1. GitHub 저장소 → Settings → Pages → Source: *Deploy from a branch*, Branch: `main`, Folder: `/docs` 선택.
2. `docs/privacy.md`가 `PRIVACY.md` 내용을 가리키도록 복사(이미 저장소 루트에 `PRIVACY.md` 있음) — 아래 명령:
   `cp PRIVACY.md docs/privacy.md && git add docs/privacy.md`
3. 몇 분 뒤 https://holyshine11.github.io/opennotch/privacy 가 열리는지 확인.

## 6. 연령 등급 설문
모든 항목 "없음" → 4+. (폭력·성·도박·의료·무제한 웹 접근·사용자 생성 콘텐츠 모두 없음. 브라우저 탭 제목을 읽지만 웹 콘텐츠를 표시하지 않음.)

## 7. 스크린샷 (2880×1800)
`docs/appstore/screenshots/` — 2026-08-29 실기 캡처를 2880×1800 캔버스에 합성(App Store Connect macOS 규격).

| 파일 | 내용 |
|---|---|
| `01-media-panel.png` | 노치 패널 — Apple Music 재생 정보·제어 |
| `02-welcome-setup.png` | 첫 실행 환영 창 — 사용법 3줄 + 브라우저 4개 모두 "제어 가능" |
| `03-settings.png` | 설정 창(일반) |

필요하면 셸프(파일 드롭)·클립보드 탭을 같은 방식으로 추가(실제 파일·클립보드 내용이 찍히므로 개인 정보 없는 상태에서 촬영).

## 8. 제출 전 체크리스트 (2026-08-29 상태)
- [x] Release 아카이브 + App Store 배포 서명 내보내기: `build/export/OpenNotch.pkg` (1.0.0 (1), Apple Distribution, Mac Team Store 프로파일 포함)
- [x] `scripts/review-check.sh` → entitlements 확인(브라우저 6 + System Events), 사설 심볼 없음, Info.plist 필수 키 OK
- [x] 개인정보 URL 200 응답: https://holyshine11.github.io/opennotch/privacy (GitHub Pages, main:/docs — **경로는 소문자**)
- [x] 스크린샷 3장(`docs/appstore/screenshots/`)
- [x] PrivacyInfo.xcprivacy: 수집 없음
- [x] App Store Connect 앱 생성 — **Apple ID 6806510254**, https://appstoreconnect.apple.com/apps/6806510254/distribution (이름 `OpenNotch`, SKU `opennotch-mac`, 기본 언어 한국어 + 영어(미국))
- [x] 빌드 1.0.0 (1) 업로드·처리·선택 완료 (2026-08-29). 재업로드 시 CFBundleVersion을 올리고 같은 명령:
  `xcodebuild -exportArchive -archivePath build/OpenNotch.xcarchive -exportOptionsPlist <UploadOptions.plist> -exportPath build/upload -allowProvisioningUpdates`
  (`UploadOptions.plist` = method `app-store-connect`, destination `upload`, teamID `MWC6DSJWJR`, signingStyle `automatic`. 또는 Transporter 앱에 `build/export/OpenNotch.pkg`를 끌어다 놓기)
- [x] 1절 기본 정보·2절 설명(ko/en)·키워드 입력, 카테고리 유틸리티/생산성, 가격 무료·175개국
- [x] 앱 개인정보(데이터 수집 안 함, 게시됨), 연령 등급 4+, 저작권
- [x] 심사 정보: 연락처 + 영어 메모(3,752자 — 앱 위치·60초 테스트·읽기 전용 설명·엔타이틀먼트 5개 용도·개인정보)
- [x] 스크린샷 3장 업로드 → 빌드 선택 → **심사 제출 완료: 2026-08-29, 상태 "1.0.0 심사 대기 중(Waiting for Review)"** — 같은 날 '정말 무료' 문구(부제·프로모션·설명·키워드 ko/en)와 영어 UI 스크린샷 3장을 넣기 위해 심사에서 한 번 내렸다가 재제출(심사 대기 중에는 스크린샷·설명 자산이 잠김, 프로모션 텍스트만 편집 가능)
- ~~반려 대비: `com.apple.systemevents` 예외가 문제면 SetupAssistant 관련 커밋(6622dec 이후)을 되돌리고 entitlements에서 그 한 줄을 지운 뒤 재제출 — 환영 창의 수동 안내는 그대로 남는다.~~

## 9. 2026-09-01 리젝(1차 심사)과 대응 — 빌드 1.0.0 (2)
Submission ID `720bc72b-e7d8-45bf-a6e5-8c505bd2b160`, 심사일 2026-09-01. 지적 3건:

| 가이드라인 | 지적 | 대응 |
|---|---|---|
| 2.3.7 (가격 언급) | 부제의 "무료/Free" | 부제에서 제거. 설명·프로모션의 '정말 무료' 문구는 유지(Apple이 설명에 쓰라고 안내) |
| 5.2.5 (Apple 상표) | 부제의 "AirDrop" | 부제·키워드에서 제거. 설명 본문의 기능 소개(참조적 사용)는 유지 |
| 2.4.5(i) (임시 예외) | `com.apple.systemevents` 승인 불가 확정 | SetupAssistant(System Events UI 스크립팅) 기능·엔타이틀먼트 제거, 수동 안내 유지. 브라우저 6개 예외와 Music scripting-targets는 지적되지 않아 유지 |

- 새 부제(ko): `노치 패널 — 셸프·클립보드·음악` / (en): `Notch shelf, clipboard & music`
- 새 키워드: 1절 참고(무료/free·AirDrop 제거)
- 빌드 (2): CFBundleVersion 2, NSAppleEventsUsageDescription에서 System Events 문장 제거
- 심사 노트(ASC 메모)에서 systemevents 단락 삭제 (3,752자 → 3,102자)
- **재제출 완료: 2026-09-01 오후 12:35, 같은 Submission ID(720bc72b…)에 빌드 (2) 교체 후 "앱 심사에 다시 제출" — 상태 "심사 대기 중"**
