# Meta Calendar for iOS

One moment, several calendar views — with method and source always visible.

## Features

- **MetaSolar-13**: Experimental 13-month calendar (13 × 28 days + bridge days)
- **Gregorian/ISO**: Standard civil calendar bridge
- **Chinese**: Lunar months, solar terms, sexagenary cycle, zodiac
- **Hijri**: Tabular, Civil, Umm al-Qura profiles — each with method/status
- **Javanese**: Saptawara, Pasaran, Weton (35-day), Wuku (210-day), Neptu
- **Astronomy**: Solar longitude, lunar phase, sunrise/sunset (optional)
- **Offline**: All calculations on-device, no account required

## Build

```bash
# Requires macOS with Xcode + XcodeGen
brew install xcodegen
xcodegen generate
xcodebuild build -project MetaCalendar.xcodeproj -scheme MetaCalendar \
  -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

GitHub Actions auto-builds on push to main.

## Architecture

- Pure Swift core engine — no UI dependencies, no OS-global state reads
- All calendar adapters independent (no cross-imports)
- Provenance tracked for every projection
- Fixed Day (Rata Die) backbone for cross-calendar conversion

## License

MIT
