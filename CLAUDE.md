# CLAUDE.md

@AGENTS.md

## Claude Code specifics

- Read `docs/STATUS.md` before starting: it has the current stage, your workstream and what is done.
- Use the `swiftui-pro` skill for SwiftUI code when it is available.
- Verify UI in the iOS Simulator (iPhone 16, iOS 18.x) launched with `-uiTesting`; take screenshots
  in light and dark mode, portrait and landscape.
- The local machine has two Xcodes: `/Applications/Xcode-26.3.app` (the `xcode-select` default, iOS 26 SDK) and
  `/Applications/Xcode.app` (16.1). The project must build with both, so keep the `#if compiler(>=6.2)` guards.
  Pick one with `DEVELOPER_DIR=/Applications/<name>.app/Contents/Developer`. Simulator runtimes: iOS 18.1, 26.3.
- You work on your own branch `ws/<name>`. At the end: commit, `git push -u origin HEAD`,
  `gh pr create` (description with the sections of the report format), then report to the orchestrator.
