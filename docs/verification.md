# Prototype verification record

Date: 2026-10-23. Platform: local Apple Silicon macOS, Apple Swift 6.3 Command Line Tools.

## Checks to record

- Rename/paste follow-up: package/product/app/display names changed to `chubby-cat`, modules to `ChubbyCat` / `ChubbyCatCore`. Workspace folder and existing bundle/preferences/Keychain identifiers stay compatible. Older README screenshots retain their original labels.
- Clipboard regression: absent standard application/Edit menus reproduced Command-V failure in text and secure fields and Command-A failure. Added standard responder-chain menus (Undo/Redo/Cut/Copy/Paste/Select All and Quit). Native checks use temporary text, wait for actual key-window activation, and restore the original clipboard contents. Final native checks pass for Command-V in text, secure and multiline chat inputs, plus Command-A. All 16 core checks, packaged-resource smoke check, signature verification and plist validation also pass.

- Core checks: **16 checks, 0 failures**, including timing, pause/snooze, checkpoint recovery, endpoint safety, Unicode/event boundaries, JSON decoding and screen placement.
- Packaged app: builds successfully with Command Line Tools; `codesign --verify --deep --strict` and plist validation pass. Signature is local ad-hoc, not notarization.
- Native resource/frame smoke check: **PASS**, 36 normalized frames, bundled master, alpha masks and nonactivating transparent panel. Initial duplicate Resources path was found and corrected; the packaged resource lookup works independently of the build-folder fallback.
- Real URLSession SSE and JSON integration: **PASS** against a localhost fixture, including fragmented network writes. Initial AsyncBytes.lines blank-line loss was replaced with a byte decoder; Unicode/boundary regression added.
- UI inspection: actual companion window launched and inspected through desktop automation; dashboard layout and all six action previews were visible. Demo button transitioned to running and back to available, while the actual timer continued. Full overlay choreography was not captured frame-by-frame; real 90-minute timing remains unverified.
- Independent review: four P2 findings fixed. Native regression checks reproduced all four failures before fixes, then passed: failed replies preserve a new draft; closing the last chat surface cancels generation; canceled connection tests cannot clear replacement-test state; failed Keychain deletion propagates an error. Keychain failure is injected at the OS-call boundary; no user credential was deleted to test it.

To repeat the native regressions while the fixture is running:

```bash
'dist/chubby-cat.app/Contents/MacOS/chubby-cat' --app-checks
```

This mode uses an isolated preferences suite, temporary localhost configuration and no real API key. The main companion app's existing preferences are not changed by these checks.

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
