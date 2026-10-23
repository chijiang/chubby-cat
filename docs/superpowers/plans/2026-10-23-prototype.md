# chubby-cat Comprehensive Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a locally runnable macOS app with the user's cartoon cat, desktop interactions, timed breaks, configurable compatible-API chat, and a polished control window.

**Architecture:** Swift Package with a pure Foundation core for scheduling and API contracts, and an AppKit/SwiftUI executable. AppKit owns nonactivating pet/reminder panels and system events; SwiftUI owns the dashboard, chat and settings. Original art is bundled unchanged; runtime rendering reads separately mapped frame regions.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, macOS 14+, AppKit, SwiftUI, URLSession, Security/Keychain, Carbon hotkeys, ServiceManagement. No downloaded dependencies.

**Spec:** docs/development-plan.md and docs/cat-animation-design.md. User authorized implementation after reviewing the proposed prototype milestone.

## Global Constraints

- macOS 14+, Apple Silicon first.
- Default reminder after 90 minutes; sustained 5-minute system break resets; 10-minute snooze does not reset elapsed time.
- Artwork source is assets/cat/animation-keyframes-v3.png; thinking poses must have no extra raised paw.
- Pet and automatic reminders do not take keyboard focus. Chat takes focus only after an explicit user action.
- API key goes to Keychain, never UserDefaults; no telemetry, no screen capture, no automatic clipboard reading.
- Current distribution: self-distributed, ad-hoc-signed preview ZIP with explicit unnotarized status. Developer ID/notarization is an optional channel; long-duration compatibility checks remain pending.

## Review Focus

- Sleep/unlock/clock adjustments must not credit inactive time or cause repeated reminders.
- A snoozed or deferred reminder must not restart as a duplicate animation.
- Endpoint changes must not send old conversation or credentials to a different provider.
- Closing chat, cancellation, fragmented SSE and malformed responses must not leave requests running indefinitely.
- Multi-monitor changes and dragging during a reminder must keep the cat visible and in a valid state.

## File Structure

- Package.swift — pure core library, app executable, XCTest targets.
- Sources/ChubbyCatCore/BreakScheduler.swift — elapsed time and break state transitions.
- Sources/ChubbyCatCore/ChatProtocol.swift — URL validation, requests, SSE and completion decoding.
- Sources/ChubbyCatCore/Geometry.swift — display-safe placement and sprite mapping.
- Sources/ChubbyCat/AppMain.swift — app lifecycle, menu bar, window ownership.
- Sources/ChubbyCat/AppModel.swift — observable app state, scheduler, reminder coordination.
- Sources/ChubbyCat/PetWindow.swift — sprite rendering, alpha hit-testing, dragging and movement.
- Sources/ChubbyCat/CompanionViews.swift — dashboard, settings, reminders, chat UI.
- Sources/ChubbyCat/ChatClient.swift — cancellable URLSession streaming and Keychain.
- Sources/ChubbyCat/SystemIntegration.swift — system events, hotkey and login support.
- Sources/ChubbyCat/Resources — bundled art.
- Tests/ChubbyCatCoreTests — scheduler and API/geometry regression tests.
- scripts/build-app.sh — build a local .app with resources and ad-hoc signature.
- README.md — run instructions and explicit prototype limitations.

### Task 1: Time and API contracts

**Interfaces:** BreakScheduler.advance(by:active:), shouldRemind, markPresented(), snooze(seconds:), skip(), completeRest(); ChatEndpoint.url(from:), ChatRequest.encoded(), SSEDecoder.append(line:); Placement.clamp(_:to:).

- [ ] Add Package.swift, empty target placeholders, and behavior tests for 90-minute boundary, one-shot reminders, short/long sleep, pause and snooze.
- [ ] Run tests; expected failure because the behavior is not implemented.
- [ ] Implement scheduling, persisted checkpoints and endpoint/request/event parsing.
- [ ] Verify endpoint normalization, insecure remote URL rejection, fragmented event parsing, provider errors and layout clamping with hand-checked fixtures.
- [ ] Run `swift test --disable-sandbox --cache-path .build/cache --manifest-cache local`; expected all tests pass.

### Task 2: Desktop pet and break choreography

**Consumes:** tested scheduler and placement. **Produces:** PetWindowController, PetSpriteView, animation atlas, cancellable movement and scale routines.

- [ ] Bundle original art and map all six animation rows to explicit source regions.
- [ ] Implement in-memory sprite normalization and alpha-based interaction; no changes to source art files.
- [ ] Implement nonactivating floating pet, drag/drop, saved position, context menu, display-safe recovery and mirrored walking.
- [ ] Implement demo and scheduled reminder: walk, enlarge, stretch, present choices, shrink, return. Generation tokens/cancellation prevent overlapping runs.
- [ ] Build executable and smoke-check bundled resources, all 36 frames and transparent interaction geometry.

### Task 3: Chat, controls and system integration

**Consumes:** scheduler and pet controller. **Produces:** usable dashboard, chat and settings windows, API client, system state tracking.

- [ ] Add warm neutral interface with restrained green accents and the user's cat as the visual identity.
- [ ] Add live timer, demo, pause/resume, snooze, rest countdown, hide/show, animation previews and manual quiet mode.
- [ ] Add API configuration, Keychain persistence, connection test, streaming/nonstreaming chat, cancellation, copy and new conversation.
- [ ] Add screen/session/sleep tracking, best-effort lock notifications, global hotkey and optional launch-at-login.
- [ ] Validate real networking against a local compatible-API fixture; no real external credentials required.

### Task 4: Package, verify and review

- [ ] Build ad-hoc-signed `dist/chubby-cat.app` and document launch/update procedure.
- [ ] Run core tests and app smoke/integration checks; launch and inspect actual UI when computer access allows.
- [ ] Request one independent whole-project review as required by executing-plans; address material correctness findings and rerun checks.
- [ ] Record tested behavior and limitations, including generated-art resolution, best-effort lock observability, unverified full-screen/multi-display cases and absence of notarization.

## Execution ledger

- Task 1 complete: 16 deterministic checks pass through `bash scripts/test.sh`. Missing-type RED runs preceded implementation; the byte-SSE regression failed before its decoder existed, then passed.
- Task 2 complete: all 36 frames loaded and normalized at runtime; packaged native smoke check passes. Corrected duplicated Resources lookup exposed by first native smoke run.
- Task 3 complete: native companion/dashboard, floating chat, settings, reminders, menu bar, hotkey, system tracking and API transport implemented. Real fragmented SSE and JSON requests pass against localhost; no real provider credentials used.
- Task 4 complete for prototype scope: app packaged, ad-hoc signature verified, native UI inspected and independent review performed. Four material review findings reproduced in native regression mode and fixed; full native checks then pass. Developer ID/public release/soak certification remain explicitly out of scope.
- Final review fixes: last-chat-window cancellation, preserving a newly typed draft after failure, connection-test generation isolation, and Keychain deletion error handling. Native regression mode showed all four failures before fixes and zero afterward.
- Deferred prototype polish: high-resolution sprite production and per-pose art cleanup. Full 90-minute and 8-hour wall-time validation, all full-screen/multi-display permutations, login-item approval and notarization remain release checks, as documented in README.

- Ruling: The directory is not a git repository. Work in the user-provided workspace; no worktree or synthetic commits. Track implementation evidence here instead of git-backed skill helper scripts.
- Ruling: The user explicitly said to go ahead with a comprehensive prototype. Execute in this chat without an additional plan-approval round.
- Ruling: Retain source art unchanged and use runtime rendering for frame extraction. Generated source is roughly 200 pixels per pose, so large Retina display remains prototype quality until higher-resolution art is produced.
