# Spotify 연동 조사 및 적용 방안 (2026-08-29)

목적: 다른 노치·미디어 앱이 Spotify를 어떻게 읽고 제어하는지 확인하고, OpenNotch(샌드박스·Mac App Store)에 맞는 방안을 고른다. **개발 착수 전 조사 문서.**

## 1. 다른 앱들은 어떻게 하나

| 앱 | 배포 | Spotify 방식 | 비고 |
|---|---|---|---|
| **boring.notch** (GPL) | 직배포 | 샌드박스 + `temporary-exception.apple-events`[`com.spotify.client`, `com.apple.Music`] + 분산 알림 `com.spotify.client.PlaybackStateChanged`로 깨어나 AppleScript 10개 값 일괄 읽기 → `artwork url` HTTP 다운로드 | 그 외 앱은 MediaRemote 어댑터(사설) |
| **Alcove / NotchNook** (비공개) | 직배포 | MediaRemote(사설 API) | macOS 15.4 이후 읽기 차단 → "Spotify·Apple Music만 정상" = 결국 AppleScript 폴백 |
| **LyricFever** (오픈소스) | 직배포 | 샌드박스 + **`scripting-targets`** {`com.spotify.client`: [`com.spotify.playback`, `com.spotify.library`]} + ScriptingBridge + `network.client`(아트워크) | 임시 예외 아님 |
| **Tuneful** ($4.99) | **Mac App Store** | Spotify + Apple Music, 온보딩에서 자동화 권한 요청 | 소스 비공개로 전환됨. MAS 통과 사례 |
| **Blink Pro** | **Mac App Store** | `scripting-targets` on `com.spotify.client` | 문자열이 `com.spotify.client.playback`으로 sdef와 다름(오타 추정) |
| **Notch Dock** (벤치마크) | Mac App Store | "미디어 컨트롤"만 표기, 방식 미공개 | — |

막힌 길:
- **Spotify Web API**: 2025-05부터 확장 쿼터 = 등록 법인 + MAU 25만 이상. 개발 모드는 사용자 5~25명 수동 등록 + 2026-02부터 앱 소유자 Premium 필수. 무료 인디 앱엔 불가.
- **MediaRemote**: 사설 프레임워크. 15.4+ 에서 `MRMediaRemoteGetNowPlayingInfo` 차단, MAS 불가.
- **미디어 키 합성(NX_KEYTYPE_PLAY)**: 대상 앱을 못 고름(브라우저와 Spotify가 같이 떠 있으면 엉뚱한 쪽이 반응).

## 2. 확정 사실 (Spotify.sdef 직접 확인, 2026-08-29 최신 DMG)

Spotify.app/Contents/Resources/Spotify.sdef 가 **정식 access-group을 선언**한다:

| access-group | 포함 항목 |
|---|---|
| `com.spotify.playback` | `application` 클래스: `current track`, `player state`, `player position`(쓰기 가능=seek), `sound volume`, `shuffling`, `repeating` / 명령: `play`, `pause`, `playpause`, `next track`, `previous track`, `play track` |
| `com.spotify.library` (읽기) | `track` 클래스: `name`, `artist`, `album`, `duration`(초), `id`, `spotify url`, **`artwork url`** (`artwork` 이미지 속성은 폐기됨) |
| `*` | Standard Suite(`name`, `version`, `frontmost`) |

→ 브라우저처럼 `temporary-exception`이 필요 없다. Apple이 권장하는 정식 경로(`com.apple.security.scripting-targets`)로 끝난다.

분산 알림 `com.spotify.client.PlaybackStateChanged` userInfo: `Name`, `Artist`, `Album`, `Album Artist`, `Player State`(Playing/Paused/Stopped), `Playback Position`(초), `Duration`(ms), `Track ID`(`spotify:track:…`), `Has Artwork`. 샌드박스 앱도 수신 가능(boring.notch가 샌드박스 상태로 사용 중). 아트워크는 없음.

Spotify 데스크톱 앱은 현재 이 Mac에 **설치돼 있지 않다** → 실제 검증 전 설치·로그인 필요.

## 3. 방안

### A. Spotify 데스크톱 앱 + `scripting-targets` — **권장**

엔타이틀먼트 추가 2개(둘 다 정식, 임시 예외 아님):

```xml
<key>com.apple.security.scripting-targets</key>
<dict>
    <key>com.spotify.client</key>
    <array>
        <string>com.spotify.playback</string>
        <string>com.spotify.library</string>
    </array>
</dict>
<key>com.apple.security.network.client</key>  <!-- 아트워크 다운로드(i.scdn.co) -->
<true/>
```

동작:
1. **읽기**: `DistributedNotificationCenter`에서 `PlaybackStateChanged` 구독 → 제목·아티스트·재생 여부·위치·길이가 이벤트로 도착(폴링 불필요). 앱 시작·패널 열 때만 AppleScript 1회 probe로 초기 상태 확보. 위치 보간은 기존 `tickTimer` 재사용.
2. **아트워크**: `artwork url of current track` → `URLSession`(640px). 트랙 ID 기준 캐시(기존 `artworkKey`).
3. **제어**: `tell application id "com.spotify.client" to playpause / next track / previous track / set player position to N` — 기존 `AppleScriptRunner`·명령 큐 그대로.
4. **권한**: 첫 Apple Event에 자동화 TCC 프롬프트 1회. 브라우저와 달리 "Apple Events의 JavaScript 허용" 같은 사용자 설정 없음 → 안내 창도 불필요.
5. **소스 우선순위**: 재생 중인 소스 > 고정(pinned) > 마지막 제어 소스. Spotify는 `BrowserKind` 후보 옆에 별도 소스로 두고, `NowPlaying`(site=`spotify`)·`MediaView`는 그대로 쓴다.

심사: `scripting-targets`는 Apple 문서상 정식 항목이라 브라우저 임시 예외보다 리스크가 낮다. Entitlement Usage 문구에 "Spotify 재생 정보 표시·재생 제어" 한 줄 추가. `network.client`는 아트워크 다운로드 용도만 명시(개인정보 수집 없음).

예상 규모: `SpotifyController.swift` ~150줄, `MediaController` 소스 추상화 소폭, 엔타이틀먼트 2키, `EntitlementsTests` 확장. 사용자 설정: "Spotify" 토글 1개.

### B. Spotify 웹 플레이어(open.spotify.com) — 후순위

기존 브라우저 경로의 URL 필터에 `open.spotify.com`을 더하면 엔타이틀먼트 추가 0. 단, 비로그인 상태에서 확인한 바 `<video>/<audio>` 요소가 없어 현재 `probeJS`(video 기반 위치·길이)가 그대로 안 맞는다 → `navigator.mediaSession` 메타데이터 + `data-testid="control-button-playpause"` 등 버튼 클릭 + 진행바 DOM 파싱으로 별도 JS가 필요하고, 로그인된 계정으로 실측해야 한다. A가 되면 굳이 필요 없음.

### C. Apple Music 덤 — 선택

같은 `scripting-targets`에 `com.apple.Music`: [`com.apple.Music.playback`, `com.apple.Music.playerInfo`] 를 더하면 Apple Music도 거의 같은 코드로 붙는다(아트워크는 `artworks`로 로컬에서 바로 읽음). 범위 확장이므로 사용자 결정 사항.

## 4. 검증 필요 / 리스크

- Spotify 설치·로그인 후 E2E: 알림 수신 → AppleScript 읽기 → 제어 → seek → 아트워크.
- Free 계정에서도 `next track`·`player position` 쓰기가 되는지(데스크톱 Free는 보통 가능).
- Spotify가 과거 sdef 경로를 깨뜨린 전력(1.0.1.988) → 오류 시 기존 backoff·상태 유지 로직 재사용.
- 알림은 Spotify가 떠 있을 때만 옴 → 종료 감지는 `NSWorkspace.didTerminateApplicationNotification`.
- App Store Connect 제출 문서(`docs/appstore/…`) 엔타이틀먼트 표 갱신.

## 5. 결정 (2026-08-29)

- **A안 제외**: 사용자가 Spotify 데스크톱 앱을 설치해 보니 "앞으로 Mac 지원 안 할 예정" 안내를 봤다고 함(공개 공지로는 macOS 12+ 지원 축소만 확인됨). 설치형에 의존하지 않기로 결정.
- **Spotify = B안**: `open.spotify.com` 웹 플레이어를 기존 브라우저 Apple Events 경로에 추가. 엔타이틀먼트 추가 없음. 로그인 계정으로 `mediaSession`·버튼 셀렉터·진행바 DOM 실측 후 별도 JS 작성.
- **Apple Music = C안 채택**: `scripting-targets` {`com.apple.Music`: [`com.apple.Music.playback`, `com.apple.Music.playerInfo`]}.
- 개발 착수는 별도 신호 후.

## 출처
- boring.notch 엔타이틀먼트·SpotifyController: https://github.com/TheBoredTeam/boring.notch
- LyricFever 엔타이틀먼트: https://github.com/aviwad/LyricFever
- Blink Pro 엔타이틀먼트: https://github.com/AGProjects/blink-cocoa
- Spotify 분산 알림 키: https://gist.github.com/loretoparisi/6092634d34e97a062029b078215b6bdc
- Spotify Web API 확장 쿼터 기준 변경: https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access
- MediaRemote 15.4 차단: https://github.com/aviwad/LyricFever/issues/94 , https://github.com/henrikruscon/alcove-releases/issues/376
- Apple 샌드박스 임시 예외 문서: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html
- Tuneful (MAS): https://apps.apple.com/us/app/tuneful-for-spotify-music/id6739804295
- Spotify.sdef: https://download.scdn.co/Spotify.dmg 의 Spotify.app/Contents/Resources/Spotify.sdef (2026-08-29 확인)
