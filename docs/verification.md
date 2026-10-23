# Prototype verification record

Date: 2026-10-23. Platform: local Apple Silicon macOS, Apple Swift 6.3 Command Line Tools.

## CAT-3 animation follow-up

- Replaced render-callback frame stepping with residual-preserving clip time. Walking phases follow actual distance, including easing and the slower return. Stretch is one-shot. Ambient observations, stretch and naps yield to explicit interactions.
- Exported 36 aligned 768px RGBA frames, manifest, contact sheet and six GIFs with `scripts/export-cat-frames.sh`. New 1536×1024 walk source has 512px cells; five other actions still use the older ~200px source detail. Full Retina art acceptance remains open.
- Native regressions reproduced and fixed: stale preview waking a resting cat; reduced motion leaving a nonzero frame visible; fractional window origins causing a 1-point downward drift on scale/return; enabling reduced motion leaving an active reminder walking. AppKit accessibility-display notifications now refresh the preference immediately.
- Core regression also reproduces and fixes an ambient stretch window shorter than its clip. The 4-second window accommodates the 1 Hz behavior tick and the 2.01-second one-shot.
- Native `--animation-checks` uses isolated preferences and no API, including a complete accelerated demo (center walk → enlarge → stretch → reminder → shrink → slower home return), canceled reminder, preview priorities and app/system reduced-motion changes. It does not substitute for a real 90-minute session or a full-day soak.
- Minor review follow-up deferred: during the 160 ms pose blend the alpha hit region follows the incoming pose, so a fading outgoing-only edge may briefly pass clicks through. No focus or keyboard handling is changed.

Final verification for this change: **21 core checks, 9 packaging checks, native animation checks (0 failures), resource smoke check and existing native app regressions all passed** on the rebuilt debug app. `scripts/build-app.sh` also passed strict ad-hoc signature verification. No Apple signing/notarization or external-provider request was performed.

## Checks to record

- Current distribution policy: self-distributed preview by default. `bash scripts/release.sh` requires no Apple account credentials and creates an explicitly unnotarized preview; `--notarized` selects the separate opt-in Developer ID/Apple workflow. Previous notarization-only requirements below describe the earlier implementation and are superseded for default packaging.
- Self-distribution verification: 16 core checks and 9 packaging checks pass. Built `dist/previews/chubby-cat-0.2.0-preview-macos-arm64.zip` with an optimized arm64 app, INSTALL.txt and distribution.json. ZIP integrity, ad-hoc signing, `notarized: false`, embedded icon, app metadata and SHA-256 verified. No external upload, Apple submission or security-setting change was performed; cross-machine first-launch remains unverified.

- Icon/release follow-up: generated cat app icon, built ten macOS icon representations into `assets/icon/AppIcon.icns`, verified the ICNS container and 1024px representation, and confirmed the exact icon is embedded with `CFBundleIconFile` in development build 0.2.0. Build, strict signature verification and plist checks pass.
- Release gates: 6 Python checks pass (missing credentials, rejecting ad-hoc release identity, requiring profile, no release-signing fallback, version validation, accepting only an explicit Accepted notarization status). The prior behavior was observed failing the initial 5 gate checks before implementation. The 16 core checks still pass.
- Actual Developer ID signing, Apple submission, stapling and final Gatekeeper acceptance are **not executed**: no usable signing identity was found, and the user reports that their developer account still needs certificate configuration. There is no certified public release artifact yet. Configuration and release commands are in `docs/release.md`.

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
- No original photo or art file was modified. Source atlas v3 remains a bundled fallback; CAT-3 adds versioned v4 walk art and offline exported runtime frames.

## Still manual / release validation

- Full 90-minute real-time interval and eight-hour performance/energy soak.
- All supported OS versions, full-screen Spaces, Stage Manager and multi-monitor permutations.
- Lock notification reliability and launch while already locked.
- Optional login-item registration, Developer ID signing and notarization.
- Independent compatibility tests with real API providers supplied by the user.
