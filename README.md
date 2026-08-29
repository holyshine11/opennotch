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
