# OpenNotch

**정말 무료입니다.** 인앱 구매·구독·잠긴 ‘프로’ 기능 없음 — 음악 제어를 포함한 모든 기능이 무료이고, 소스도 공개되어 있습니다.

A free, open-source utility that turns the MacBook notch into a tiny control center — AirDrop drop zone, YouTube / YouTube Music controls, clipboard history, and a file shelf. Sandboxed, no private APIs, built for the Mac App Store.

## Status
Work in progress (P1: notch window). See `docs/strategy` and `docs/superpowers` for the plan.

## Build
Requires Xcode 26.6+ and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test
```

## License
MIT — see `LICENSE`.

## 권한
- **자동화(Apple Events)**: 브라우저(Safari·Chrome·Edge·Arc·Brave·Whale)의 YouTube/Spotify 탭과 Apple Music의 재생 정보를 읽고 재생/일시정지를 보내기 위해. 패널이 열려 있을 때만 요청합니다.
- 네트워크·분석·계정 없음. 모든 데이터는 이 Mac에만 저장됩니다.
