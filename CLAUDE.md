# CLAUDE.md

@AGENTS.md

## Claude Code specifics

- Read `docs/STATUS.md` before starting: it has the current stage, your workstream and what is done.
- Use the `swiftui-pro` skill for SwiftUI code when it is available.
- Verify UI in the iOS Simulator (iPhone 16, iOS 18.x) launched with `-uiTesting`; take screenshots
  in light and dark mode, portrait and landscape.
- The local machine is on Xcode 16.1 for now: no iOS 26 SDK, so `#if compiler(>=6.2)` branches don't compile.
  Don't remove them; they are needed for Xcode 26.
- You work on your own branch `ws/<name>`. At the end: commit, `git push -u origin HEAD`,
  `gh pr create` (description with the sections of the report format), then report to the orchestrator.
