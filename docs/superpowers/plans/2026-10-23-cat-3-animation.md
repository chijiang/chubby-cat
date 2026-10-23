# CAT-3 Animation and Behavior Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for native implementation, with test-driven-development and verification-before-completion.

**Goal:** Make the existing cat move and react naturally, with aligned clean sprites and inspectable animation previews.

**Architecture:** Keep Swift/AppKit. Move animation timing, gait phase and calm ambient behavior into Foundation-only types. PetWindow owns motion and rendering; AppModel arbitrates reminder, chat, preview, rest and ambient behavior. Export aligned runtime frames from a versioned source sheet rather than recropping art at launch.

**Tech Stack:** Swift, AppKit, CoreGraphics, existing framework-free checks; built-in imagegen for new source art.

**Spec:** docs/cat-animation-design.md and CAT-3 in https://linear.app/chubby-cat/issue/CAT-3, plus the user's request for more lively and reasonable behavior.

## Global Constraints

- macOS 14+, Apple Silicon; no new external dependencies or permissions.
- Retain the user's silver tabby identity, correct four-legged anatomy, six existing action groups.
- No unrequested wandering, focus stealing, screen reading or API calls for pet behavior.
- Reduced motion remains static; hidden/locked states do not accumulate a burst of ambient actions.
- Preserve original source artwork. Report the actual resolution and quality boundary honestly.

## Review Focus

- Delayed render ticks preserve residual timing; invalid elapsed values do not advance frames.
- Gait follows actual traveled distance, including slow return and easing; zero distance does not walk.
- Ambient sleep/stretch cannot overwrite drag, preview, API response, rest or reminder states.
- Cancellation restores a usable pose without an older animation changing a newer animation.
- Clean sprites retain white paws, whiskers and correct alpha hit regions; scaling fixes a common paw anchor.

### Task 1: Timing, gait and ambient behavior

**Files:** Sources/ChubbyCatCore/CatAnimation.swift, Tests/ChubbyCatCoreTests/CatAnimationTests.swift, Tests/ChubbyCatCoreTests/main.swift.

**Interfaces:** CatAction, AnimationPlayback, CatMotion and AmbientBehavior are shared by native rendering and tests.

- [x] Write failing checks for timing remainder/long ticks, one-shot completion, invalid deltas, gait distance, anchor-preserving scale, ambient cooldown and interruption priority.
- [x] Run bash scripts/test.sh and observe failures before implementation.
- [x] Implement pure types and run the complete core checks.

### Task 2: Native animation and behavior coordination

**Files:** Sources/ChubbyCat/PetWindow.swift, Sources/ChubbyCat/AppModel.swift, Sources/ChubbyCat/CompanionViews.swift.

**Interfaces:** Consume Task 1; sprite supports short pose blending, distance-driven walking, and deterministic preview. Ambient behavior only owns idle states and resets on interactions.

- [x] Integrate monotonic deltas, anchored scaling and gait, short crossfade, calmer thinking/talking, attention and nap behavior.
- [x] Verify interruption, reduced motion and no zero-distance walking with native checks.
- [x] Build packaged app and run native smoke checks.

### Task 3: Runtime artwork and preview

**Files:** versioned assets/cat source, runtime frames and manifest, export/preview tooling, build-app.sh, animation documentation.

- [x] Inspect generated art; reject anatomical defects and never silently substitute low-quality art.
- [x] Export clean aligned frames using a common body scale and foot anchor, keeping white fur and whiskers.
- [x] Add actual runtime-frame contact sheet and animated previews, inspect idle/walk/stretch/think/talk/sleep.
- [x] Run all core, packaging and native checks; record evidence and remaining visual limits. Update Linear with progress, leaving it In Progress if asset acceptance remains unfinished.

## Remaining acceptance

- [ ] Redraw idle/stretch/think/talk/sleep with genuine higher-resolution detail; inspect at Retina 1.8× before closing CAT-3.
- [ ] Final manual art polish and small crossfade alpha-hit-region follow-up (outgoing-only edge).

Implemented in the existing checkout under user authorization; no commit or deployment requested.
