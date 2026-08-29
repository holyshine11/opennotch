# P6 — Apple Music 소스 + Spotify 웹 플레이어 (2026-08-29)

근거: `docs/strategy/2026-08-29-spotify-integration-research.md` §5 (Spotify 설치형 제외, 웹 플레이어 B안 + Apple Music C안). 라이트 모드(메인 세션 직접 구현, 최종 리뷰 1회 + 실기 QA 1회).

## 범위
1. **Apple Music**: `scripting-targets` {`com.apple.Music`: [`com.apple.Music.playback`, `com.apple.Music.library.read`]} 정식 엔타이틀먼트. 임시 예외 아님. (Music.sdef 실측: `track`·`player state/position`·명령은 playback, `artwork.raw data`는 library.read)
2. **Spotify 웹**: `open.spotify.com` 탭을 기존 브라우저 경로에 추가. 엔타이틀먼트 변경 없음. **로그인 계정에서 DOM 실측 후** JS 작성(사용자가 Whale에 open.spotify.com 열어 두면 `osascript`로 측정).

## 설계 (최소 diff)
- `BrowserKind`에 `.appleMusic = "com.apple.Music"` 추가 + `isBrowser`. 설정 토글 목록엔 포함(끌 수 있게), 안내 창·temporary-exception 목록은 `BrowserKind.browsers`만.
- `MediaScript.probe(.appleMusic)` → Music AppleScript. 출력 `MUSIC\t재생중\t위치\t길이\t제목\t아티스트\tpersistentID`. `parseProbe`가 Swift에서 `NowPlaying(site: "apple_music")`으로 조립해 `ProbeResult.json`에 넣는다 → `MediaController.apply`는 그대로. `ProbeResult.trackID` 추가(아트워크 키).
- 아트워크: 트랙 ID가 바뀔 때만 `raw data of artwork 1 of current track` 1회. `AppleScriptRunner.runData` 추가(descriptor.data).
- 명령: `playpause/play/pause/next track/previous track`, seek = `set player position to (duration of current track) * f`. `activate` = 앱 앞으로.
- 우선순위·전환 버튼·틱 보간은 기존 후보 로직 재사용(Music은 후보 하나).

## 태스크
- [x] T1 BrowserKind·설정·안내 창 분기, EntitlementsTests 갱신(scripting-targets 검증), 엔타이틀먼트 추가
- [x] T2 MediaScript Music 스크립트 + parseProbe + 테스트
- [x] T3 MediaController 아트워크 경로 + runData
- [x] T4 실기 QA (Music.app 재생 → 패널 표시·제어·seek·아트워크)
- [x] T5 Spotify 웹 DOM 실측 → probe/command JS 확장 + 테스트 + QA
- [x] T6 스펙 §4.8·App Store 제출 문서 엔타이틀먼트 표 갱신, 최종 리뷰 1회, 커밋

## 결과 (2026-08-29)
- 커밋 전 실기 QA: Apple Music(라디오)·Spotify 웹(Whale)·YouTube(Safari) 3소스 표시·전환·아트워크 확인, probe 오류 0건.
- 발견·수정: ① Music 저장 참조(`set t to current track` → `name of t`)는 샌드박스 scripting-targets에서 -10004 → 매번 `current track` 경유. ② 한 소스 오류가 전체 30초 백오프 → 소스별 백오프. ③ 브라우저 아트워크는 0.7초 뒤 재폴링. ④ 소스 전환 순서 고정. ⑤ Music 라디오는 길이 없음(seek 비활성) — 아트워크는 Music 자체가 일시정지 중 이전 곡 것을 돌려줌(앱 문제 아님).
- 검증 도구: 같은 엔타이틀먼트로 서명한 샌드박스 CLI(스크래치패드 `sb/sbtest`, Info.plist를 `__info_plist` 섹션에 심어야 컨테이너 생성됨)로 스크립트 단위 이분 탐색.
