# Prototype verification record

Date: 2026-10-23. Platform: local Apple Silicon macOS, Apple Swift 6.3 Command Line Tools.

## Checks to record

- Core checks: pending final run.
- Packaged app build and ad-hoc signature: build completed; final verification pending.
- Native resource/frame smoke check: first check correctly exposed a duplicate Resources path; corrected and awaiting rerun.
- Real URLSession SSE and JSON integration: first check exposed blank-line loss in AsyncBytes.lines; switched to a byte decoder that preserves SSE boundaries; awaiting rerun.
- UI inspection: first launch timed out because the bundled-art lookup crashed before creating the window; retry after the resource fix.

## Decisions and scope

- No existing git repository; changes are in the supplied project directory, without a worktree or commits.
- Full Xcode is installed but its license has not been accepted. The agent did not accept it. The app builds with Command Line Tools; regression checks use an explicit executable test harness rather than XCTest.
- No user API key, external provider call, automatic startup setting or deployment was needed to build and verify the prototype.
- No original photo or art file was modified. Source atlas v3 is copied into resources; frame normalization happens inside the app renderer.

## Still manual / release validation

- Full 90-minute real-time interval and eight-hour performance/energy soak.
- All supported OS versions, full-screen Spaces, Stage Manager and multi-monitor permutations.
- Lock notification reliability and launch while already locked.
- Optional login-item registration, Developer ID signing and notarization.
- Independent compatibility tests with real API providers supplied by the user.
