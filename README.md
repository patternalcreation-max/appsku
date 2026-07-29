# K3 Calculator 🔢🧊

Calculator iOS app built with SwiftUI. Auto-builds IPA via GitHub Actions macOS runner.

## Quick start

1. Fork / push this repo to your GitHub
2. Go to **Actions** tab → "Build IPA" workflow runs automatically
3. Download `k3-calculator.ipa` from the workflow artifacts
4. Add to Feather/KSign via repo URL or manual install

## Features

- Standard calculator: +, −, ×, ÷
- AC, +/−, %
- Decimal support
- Expression line (shows full calculation)
- Dark mode with gradient background
- Works offline, no internet needed

## Build your own version

```bash
# Edit the Swift files, then push to trigger rebuild:
git add .
git commit -m "update"
git push
```

GitHub Actions will auto-build a new IPA. Download from Actions tab → latest run → Artifacts.

## Repo manifest for Feather/KSign

Edit `apps.json` — replace `USERNAME/REPO` with your actual GitHub username and repo name. Then add the raw URL as a repo source in Feather/KSign.

## Tech

- SwiftUI + UIKit lifecycle
- iOS 16.0+
- XcodeGen for project generation
- Unsigned IPA (signed at install time by Feather/KSign)
