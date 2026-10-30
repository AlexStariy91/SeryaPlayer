# SeryaPlayer

An offline audio player for iPhone, built with SwiftUI.

- Music from your own files: Files app, Finder, Share sheet, a download link, the built-in browser
- Folders (how files are stored) and playlists (collections)
- 10-band equalizer with 16 built-in presets and custom presets
- Apple Music–style design; Liquid Glass on iOS 26, materials on iOS 18
- Background playback, Lock Screen controls, AirPods
- Themes (system, light, dark) and an accent color, `#1C283F` by default
- iPhone only, portrait and landscape
- Localized in English and Russian

App Store release is not planned yet, but everything is set up so it can be submitted without rework.

## Requirements

| | |
|---|---|
| iOS | 18.0+ (with dedicated iOS 26 polish) |
| Xcode | 16.1+ (Xcode 26 for Liquid Glass) |
| Swift | 6, strict concurrency |
| Tools | `brew install xcodegen swiftlint swiftformat` |

## Getting started

```bash
git clone git@github.com:AlexStariy91/SeryaPlayer.git
cd SeryaPlayer
xcodegen generate
open SeryaPlayer.xcodeproj
```

`.xcodeproj` is not checked in: it is generated from `project.yml`. This avoids `project.pbxproj`
conflicts during parallel work. Run `xcodegen generate` again after `git pull`.

To run on a device, select your Team in Xcode → Signing & Capabilities
(or set `DEVELOPMENT_TEAM` in `project.yml` locally without committing it).

## Tests

```bash
scripts/test.sh unit   # unit tests of all packages
scripts/test.sh ui     # UI and snapshot tests
```

CI (GitHub Actions) runs the build, unit tests and linters on every push to `main` and on every PR;
UI tests run on PRs.

## Layout

```
App/                 app target: Composition Root (AppContainer, RootView, AppRouter)
AppUITests/          UI tests
Packages/
  Domain/            entities, protocols, use cases, QueueEngine — Foundation only
  DataLayer/         Core Data, files, metadata, artwork, settings
  Playback/          AVAudioEngine, audio session, Now Playing, PlaybackService
  Shared/            App Group, storage paths
  DesignSystem/      colors, typography, adaptiveGlass, shared components
  *Feature/          screens: Library, Folders, Player, Equalizer, Browser, Settings
docs/                ARCHITECTURE.md, STATUS.md
```

More in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Progress: [docs/STATUS.md](docs/STATUS.md).
Rules for contributors and AI agents: [AGENTS.md](AGENTS.md).
