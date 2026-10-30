# AGENTS.md — rules for every agent and human working on SeryaPlayer

Any AI agent (Claude Code, Codex, Cursor, etc.) reads this file before starting work.
`CLAUDE.md` includes it in full.

## What this is

SeryaPlayer is an offline audio player for iPhone built with SwiftUI: music from the user's own files,
folders and playlists, a 10-band equalizer, Apple Music–style design with Liquid Glass on iOS 26.
Overview: [README.md](README.md). Design: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Progress and what's next: [docs/STATUS.md](docs/STATUS.md).

## Language

**Everything in the repository is in English**: code, identifiers, comments, docs, commit messages,
branch names, PR titles and descriptions, issues, review comments, test names, script output.
User-facing UI strings are written in English in code and translated in the String Catalog
(`Localizable.xcstrings`); Russian (`ru`) is a required translation, so every new UI string needs a
`ru` entry.

## Commands

```bash
xcodegen generate          # .xcodeproj is not in git; it is generated from project.yml
scripts/test.sh unit       # build + unit tests of all packages (iOS 18 simulator)
scripts/test.sh ui         # UI and snapshot tests
swiftformat . && swiftlint --strict
```

Fast loop for packages without UIKit/SwiftUI (Domain, Shared, DataLayer): `cd Packages/Domain && swift test`.
Packages that use SwiftUI or AVAudioSession are tested only through `scripts/test.sh`.

## Hard architecture rules

1. **Layers are SPM packages**; the compiler enforces the boundaries. Do not add a dependency to a
   `Package.swift` that is not in the table in ARCHITECTURE.md. Features depend only on `Domain` and `DesignSystem`.
2. **Domain imports only Foundation.** No SwiftUI, CoreData, AVFoundation or Observation.
   Entities are immutable `Sendable` structs.
3. **Features don't know about each other.** Navigation goes through `AppRouter` in the App target.
4. **DI through `init` only.** No singletons and no service locator; `@Environment` is only for
   cross-cutting UI concerns (router, theme, accent). Everything is assembled in `AppContainer`.
5. **MVVM:** `@MainActor @Observable final class …ViewModel`, dependencies through `init`.
6. **`#available(iOS 26, *)` only inside DesignSystem.** Also wrap Liquid Glass APIs in
   `#if compiler(>=6.2)` while the project must still build with Xcode 16.
7. Don't paint the nav bar / tab bar background (`.toolbarBackground`): it kills the glass. No glass on glass.
8. **Swift 6, strict concurrency complete.** Data-race diagnostics are errors. Don't silence them with
   `@unchecked Sendable` / `nonisolated(unsafe)` without a comment explaining why it is safe.
9. **Domain contracts** (`Packages/Domain/Sources/Domain/{Entities,Repositories,Services}`) are shared by
   all workstreams. They may change, but such a change is a separate, explicitly described item in the PR,
   and all implementations and mocks must keep compiling.

## Style

- Swift Testing (`import Testing`, `@Test`, `#expect`) in packages; XCTest only for UI tests.
- Before committing: `swiftformat .`, `swiftlint --strict`, `scripts/test.sh unit` — all green.

## Parallel work

- Work is split into **workstreams**; see the table in STATUS.md. One workstream = one session =
  one branch `ws/<name>` = one PR into `main`.
- A workstream touches only its own files (its package/folder). If it needs a change in another package
  or in a Domain contract, keep it minimal and call it out in the PR and the report.
- `project.yml` and `App/` (Composition Root) are owned by the orchestrator. If a workstream needs
  something wired into `AppContainer`, it describes it in the report and the orchestrator does it.
- `docs/STATUS.md` is edited only by the orchestrator. Workstreams describe their results in the PR and report.

### Report format for the orchestrator (the session's last message)

```
Workstream: <name>    Branch: ws/<name>    PR: <link>
Done: …
Tests: what was added; result of scripts/test.sh unit (green/red + error output)
Changes to Domain contracts / other packages: … (or "none")
Needed from the orchestrator (App/AppContainer/project.yml): …
Not done / risks / manual on-device checks: …
```

## Git

- `main` is protected by convention: only the orchestrator commits directly (docs, Composition Root).
- Keep history clean: one logical change per commit, imperative mood, scope prefix —
  `Domain: implement QueueEngine`, `CI: cache SPM packages`. Squash fixups before pushing a PR.
- No secrets, keys or `DEVELOPMENT_TEAM` in the repository. Signing is configured locally.
