# SeryaPlayer architecture

The source of these decisions is the "SwiftUI audio player — development plan" document. This file
holds what you need to keep in mind while writing code. Update it whenever a decision changes.

## Key decisions

| Topic | Decision | Why |
|---|---|---|
| Minimum iOS | 18.0, with dedicated iOS 26 polish | Tab API, MeshGradient, zoom transitions; Liquid Glass on 26 |
| Language | Swift 6, strict concurrency complete | Data races caught at compile time |
| Architecture | Clean Architecture, layers as local SPM packages | The compiler enforces boundaries |
| DI | Constructor injection + Composition Root, no libraries | Explicit dependencies, easy mocks |
| Database | Core Data (not SwiftData) | Reliable on iOS 18; `@Query` isn't needed since views work with Domain types |
| Audio | AVAudioEngine + AVAudioUnitEQ | EQ, rate, gapless and visualizer in one graph |
| Files | Copied into the App Group container | Survive deletion of the original; reachable from the Share Extension |
| Project | XcodeGen (`project.yml`), `.xcodeproj` not in git | No pbxproj conflicts during parallel work |
| Tabs | Library · Folders · Browser (behind a flag) | Search lives in lists; EQ opens from the player |
| Devices | iPhone only, portrait + landscape | Requirement |
| Localization | English source strings, Russian translation | Requirement |

## Modules and dependencies

All dependencies point inward, toward Domain. Everything is assembled only in the App target.

```
                       ┌──────────── App (Composition Root) ────────────┐
                       │ AppContainer · RootView · AppRouter · Flags     │
                       └──┬──────────┬──────────┬──────────┬─────────────┘
                          │          │          │          │
                 *Feature packages  DataLayer  Playback   Shared
                    │      │          │   │       │
              DesignSystem │          │  Shared   │
                           ▼          ▼           ▼
                         ┌──────────────────────────┐
                         │   Domain (Foundation)    │
                         └──────────────────────────┘
```

| Module | Contents | Depends on |
|---|---|---|
| `Domain` | Entities, repository and service protocols, use cases, `QueueEngine`, EQ math, built-in presets | Foundation |
| `DataLayer` | Core Data stack, repositories, mappers, `FileStore`, `MetadataReader`, `ArtworkCache`, `InboxProcessor` | Domain, Shared |
| `Playback` | `AudioSessionManager`, `AVAudioPlaybackEngine`, `NowPlayingCenter`, `RemoteCommands`, `DefaultPlaybackService` | Domain |
| `Shared` | `AppGroup.id`, `StoragePaths`, `InboxWriter` (for extensions) | — |
| `DesignSystem` | Colors, typography, `adaptiveGlass`, `adaptiveButtonStyle`, `miniPlayerHost`, `ArtworkView`, `TrackRow`, sliders | — |
| `LibraryFeature`, `FoldersFeature`, `PlayerFeature`, `EqualizerFeature`, `BrowserFeature`, `SettingsFeature` | SwiftUI views + `@Observable` view models + a feature factory | Domain, DesignSystem |
| `App` | `AppContainer`, `PreviewContainer`, `RootView`, `AppRouter`, `FeatureFlags` | everything |
| `ShareExtension` (stage 8) | Drops received files into the Inbox | Shared |

> The data package is named `DataLayer`, not `Data`, to avoid clashing with `Foundation.Data`.

## Layer rules

- Domain doesn't import SwiftUI, Core Data or AVFoundation. Entities are immutable structs.
- Features know only Domain protocols and use cases and don't depend on each other; navigation goes through `AppRouter`.
- MVVM: `@MainActor @Observable final class …ViewModel`, dependencies through `init`.
- Each feature exports a `…Dependencies` protocol and a view factory; `AppContainer` conforms to those protocols.
- Playback progress is not part of `PlaybackSnapshot`: `PlayerFeature` polls
  `PlaybackControlling.currentTime` with its own small `@Observable PlaybackProgress`, only while the
  player is on screen, so frequent updates redraw only the timeline.
- Lifetimes: the stack, repositories and player are single instances (lazy in the container); use cases and view models are per screen.
- `PreviewContainer` (previews, UI tests via the `-uiTesting` argument) uses in-memory repositories and mocks.
- Localized strings inside packages use the package's own String Catalog and `bundle: .module`.

## Feature package contract (wave 2)

Every `*Feature` package exposes the same shape, so the orchestrator can wire it in `App/` without
touching the feature:

```swift
@MainActor
public protocol LibraryDependencies {          // one per feature: <Name>Dependencies
    var trackRepository: any TrackRepository { get }
    var player: any PlaybackControlling { get }
    // …only Domain protocols, use cases and plain values
}

public enum LibraryFeature {                   // one per feature: <Name>Feature
    @MainActor
    public static func makeRootView(
        dependencies: some LibraryDependencies,
        onOpenSettings: @escaping () -> Void    // cross-feature hooks are closures or @ViewBuilder parameters
    ) -> some View
}
```

- `AppContainer` conforms to every `…Dependencies` protocol. Property names must match the
  container's existing ones (`trackRepository`, `folderRepository`, `playlistRepository`,
  `presetRepository`, `settingsRepository`, `fileStore`, `artworkStore`, `metadataReader`, `player`,
  `importTracks`). If a feature needs something new, it adds a requirement and lists it in its report.
- Cross-feature navigation is never an import: Player gets the equalizer sheet as a `@ViewBuilder`,
  Library gets `onOpenSettings`, Settings gets the preset manager as a `@ViewBuilder`.
- Artwork: features resolve `Track.artworkKey` through `ArtworkStoring.url(for:size:)` and pass the URL to `ArtworkView`.
- Each feature has its own `Resources/Localizable.xcstrings` (`defaultLocalization: "en"`, `bundle: .module`) with `ru`.
- Tests: view-model tests with Swift Testing and `DomainTestSupport` fakes (test target only), and
  snapshot tests with `swift-snapshot-testing` (exact version `1.17.6`, test target only).
  App-level UI tests are written by the orchestrator after wiring.

### Shared-file ownership during wave 2

Domain and DataLayer are shared. To avoid conflicts, only the owner changes these files; anyone else
asks in their report:

| Area | Owner |
|---|---|
| `TrackRepository`, `PlaylistRepository`, `TrackSort`, track/playlist use cases + their Core Data repos | `library` |
| `FolderRepository`, folder use cases + `CoreDataFolderRepository` | `folders` |
| `EQPresetRepository`, equalizer use cases + `CoreDataEQPresetRepository` | `equalizer` |
| `PlaybackControlling`, `DefaultPlaybackService` | `player` |
| `AppSettings`, `SettingsRepository` | `settings` |

New use cases go into new files. Adding a protocol requirement means updating the Core Data/Playback
implementation and the `DomainTestSupport` fakes in the same PR.

## Domain contracts (stage 0)

- `Entities/` — `Track`, `Folder`, `Playlist`, `PlaylistEntry`, `TrackSort`, `ImportResult`,
  `PlaybackState`, `PlaybackSnapshot`, `RepeatMode`, `EQPreset`, `EQSettings`, `EQBands`, `AppSettings`.
- `Repositories/` — `TrackRepository`, `FolderRepository`, `PlaylistRepository`,
  `EQPresetRepository`, `SettingsRepository`, `PlaybackStateRepository`.
  Every `observe…()` returns a new `AsyncStream` per subscriber, starting with the current state.
- `Services/` — `FileStoring`, `MetadataReading`, `ArtworkStoring`, `PlaybackEngine` (@MainActor,
  low level), `PlaybackControlling` (@MainActor, used by features), `NowPlayingPublishing`.
- `Queue/QueueEngine` — pure queue logic (API fixed; implementation in stage 1).

## Data storage

Core Data + files in the App Group container (Application Support on an unsigned simulator build).

| Entity | Key fields | Relationships |
|---|---|---|
| `CDTrack` | id, title, artist, album, albumArtist, trackNumber, duration, relativePath, originalFileName, fileSize, contentHash, artworkKey, dateAdded, playCount, lastPlayedAt | folder (to-one), entries → CDPlaylistEntry (to-many, cascade) |
| `CDFolder` | id, name, sortIndex, createdAt | parent (to-one), subfolders (to-many, cascade), tracks (to-many) |
| `CDPlaylist` | id, name, createdAt, coverArtworkKey | entries (to-many, cascade) |
| `CDPlaylistEntry` | id, sortIndex | playlist (to-one), track (to-one) |
| `CDEQPreset` | id, name, gains (10 × Float, JSON), preamp, createdAt | — |

- Built-in presets live in code; only user presets are stored.
- Settings: `UserDefaults(suiteName: AppGroup.id)` behind `SettingsRepository`.
- Player state: `PlaybackState.json`, written when going to background.
- Deleting a folder: the use case asks "delete tracks / move to root" (`FolderDeletionPolicy`).

```
<App Group>/Library/
  SeryaPlayer.sqlite
  Media/<uuid>.<ext>        ← copied audio files
  Artwork/<hash>.jpg        ← artwork + downscaled copies
  Inbox/                    ← written by the Share Extension
  PlaybackState.json
App Documents/Inbox/        ← visible in Finder and the Files app
```

- Only relative paths in the database. File names are UUIDs; the original name is stored in the database.
- Duplicates are detected by `contentHash` (size + SHA-256 of the first 1 MB).
- Artwork is stored on disk by hash, so all tracks of an album share one file.
- `InboxProcessor` picks up files from both inboxes on every activation and runs them through the regular import.
  The extension never writes to the database.

## Audio

Graph: `AVAudioPlayerNode → AVAudioUnitTimePitch → AVAudioUnitEQ (10 bands) → mainMixer`.

- Seeking uses `scheduleSegment`; end of track uses `.dataPlayedBack` + a generation counter.
- `AVAudioEngineConfigurationChange` and sample-rate changes → reconnect nodes.
- Audio session `.playback`; interruptions honor `shouldResume`; pause when headphones are unplugged;
  rebuild on media services reset.
- EQ: ±12 dB, auto preamp = −max(positive gain).

## UI on iOS 18 and iOS 26

One UI codebase; the differences are hidden in DesignSystem.

| Element | iOS 18 | iOS 26 |
|---|---|---|
| Tab bar | `TabView` + Tab API | + Liquid Glass, `.tabBarMinimizeBehavior(.onScrollDown)` |
| Mini player | Overlay above the tab bar, `.regularMaterial` | `.tabViewBottomAccessory` |
| Custom panels | `.background(.ultraThinMaterial, in:)` | `.glassEffect(_:in:)`, `GlassEffectContainer` |
| Buttons | `.bordered` / `.borderedProminent` | `.glass` / `.glassProminent` |
| Full player background | `MeshGradient` from artwork colors | same |
| Mini → full | `.matchedTransitionSource` + `.navigationTransition(.zoom)` | same |

- Theme via the window's `overrideUserInterfaceStyle`; accent via `.tint` on the root view.
- `verticalSizeClass == .compact` → player in two columns; EQ with the graph on the left and presets on the right.
- Every screen is checked on iOS 18.x and 26.x, light/dark, portrait/landscape.

## Current toolchain

Locally Xcode 16.1 (iOS 18.1 SDK). Liquid Glass code is wrapped in `#if compiler(>=6.2)` and
turns on automatically after moving to Xcode 26. Once Xcode 26 is installed: verify the build and add
an iOS 26 simulator to `scripts/test.sh` and CI.
