# OpenNotch

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
- **손쉬운 사용(선택)**: 설정 창의 "메뉴 열어 주기"를 누를 때만 System Events로 브라우저의 보기 › 개발자 메뉴를 열어 줍니다(Safari는 설정의 체크박스까지). 화면을 읽거나 기록하지 않으며, 권한 없이도 수동 안내로 동일하게 설정할 수 있습니다.
- 네트워크·분석·계정 없음. 모든 데이터는 이 Mac에만 저장됩니다.
