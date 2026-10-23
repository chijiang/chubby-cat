import AppKit
import ChubbyCatCore

@MainActor enum AnimationChecks {
    static func run() async {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) { if !condition { failures.append(message) } }
        let sprite = PetSpriteView(frame: CGRect(x: 0, y: 0, width: 190, height: 190))
        sprite.action = .talk; sprite.step(0.49)
        check(sprite.frameIndex == 3, "native playback dropped timing remainder")
        sprite.reducedMotion = true
        check(sprite.frameIndex == 0, "reduced motion did not immediately select static pose")
        sprite.reducedMotion = false; sprite.action = .walk; sprite.travelDistance = 34.2
        sprite.step(0.01)
        check(sprite.frameIndex == 1, "native walking ignored distance")
        sprite.step(2)
        check(sprite.frameIndex == 1, "stationary paws kept walking")

        let suite = "com.deskkitty.animation-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        var systemReducedMotion = false
        let model = AppModel(defaults: defaults, systemReducedMotion: { systemReducedMotion })
        defer { model.shutdown(); model.pet.hide(); defaults.removePersistentDomain(forName: suite) }
        let area = model.pet.screen.visibleFrame
        model.pet.show(at: NSPoint(x: area.midX - 250, y: area.midY - 95))
        let home = model.pet.panel.frame
        let anchor = home.minY + home.height * CatMotion.footAnchor
        do {
            try await model.pet.scale(to: 342, reduced: true)
            check(abs(model.pet.panel.frame.minY + 342 * CatMotion.footAnchor - anchor) <= 0.5, "scaling lifted paws beyond window-coordinate rounding")
            try await model.pet.scale(to: 190, reduced: true)
            model.pet.sprite.action = .idle
            try await model.pet.move(to: model.pet.panel.frame.origin, speed: 100, reduced: false)
            check(model.pet.sprite.action == .idle, "zero distance started a walk")
        } catch { failures.append("motion check: \(error)") }

        model.preview(.think); model.startRest()
        try? await Task.sleep(nanoseconds: 3_200_000_000)
        check(model.pet.sprite.action == .sleep, "old preview woke resting cat")
        model.cancelRest()
        model.preview(.stretch); model.openChat()
        check(model.pet.sprite.action == .idle, "chat did not cancel preview")
        model.beginReminder(demo: true)
        try? await Task.sleep(nanoseconds: 150_000_000)
        model.cancelReminder(restoreHome: true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(!model.reminderActive && model.pet.sprite.action == .idle, "canceled reminder kept walking")
        check(hypot(model.pet.panel.frame.minX - home.minX, model.pet.panel.frame.minY - home.minY) < 1, "cancellation lost home")
        model.beginReminder(demo: true)
        let deadline = ProcessInfo.processInfo.systemUptime + 24
        var sawBubble = false
        while model.reminderActive && ProcessInfo.processInfo.systemUptime < deadline {
            sawBubble = sawBubble || model.reminderMessageVisible
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        check(sawBubble && !model.reminderActive, "complete demo never reached bubble and returned")
        check(hypot(model.pet.panel.frame.minX - home.minX, model.pet.panel.frame.minY - home.minY) < 1, "complete demo did not return home")
        model.beginReminder(demo: true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        model.settings.reducedMotion = true; model.saveSettings()
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(!model.reminderActive && model.pet.sprite.action == .idle, "enabling reduced motion left reminder movement active")
        model.settings.reducedMotion = false; model.saveSettings()
        model.beginReminder(demo: true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        systemReducedMotion = true; model.motionPreferenceChanged()
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(model.reducedMotion && model.pet.sprite.reducedMotion && !model.reminderActive, "system reduced-motion change did not stop active reminder")
        for failure in failures { print("ANIMATION FAIL: \(failure)") }
        print("ANIMATION CHECKS: \(failures.count) failures (timing, reduced motion, gait, anchor, preview priority, cancellation, complete reminder)")
        exit(failures.isEmpty ? 0 : 1)
    }
}
