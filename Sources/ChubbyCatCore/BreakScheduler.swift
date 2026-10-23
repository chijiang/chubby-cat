import Foundation

public struct BreakCheckpoint: Codable {
    public var elapsed: Double
    public var snoozeRemaining: Double
}

public struct BreakScheduler {
    public var interval: Double
    public var restThreshold: Double
    public private(set) var elapsed: Double
    public private(set) var snoozeRemaining: Double = 0
    public private(set) var presented = false
    private var inactiveElapsed: Double = 0

    public init(interval: Double = 5400, restThreshold: Double = 300, elapsed: Double = 0) {
        self.interval = interval.isFinite ? max(1, interval) : 5400
        self.restThreshold = restThreshold.isFinite ? max(1, restThreshold) : 300
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
    }

    public init(checkpoint: BreakCheckpoint, interval: Double = 5400, restThreshold: Double = 300) {
        self.init(interval: interval, restThreshold: restThreshold, elapsed: checkpoint.elapsed)
        snoozeRemaining = checkpoint.snoozeRemaining.isFinite ? max(0, checkpoint.snoozeRemaining) : 0
    }

    public var checkpoint: BreakCheckpoint { .init(elapsed: elapsed, snoozeRemaining: snoozeRemaining) }
    public var shouldRemind: Bool { elapsed >= interval && snoozeRemaining <= 0 && !presented }
    public var remaining: Double { snoozeRemaining > 0 ? snoozeRemaining : max(0, interval - elapsed) }

    public mutating func advance(by seconds: Double, active: Bool, paused: Bool = false) {
        guard seconds.isFinite, seconds >= 0 else { return }
        if !active {
            inactiveElapsed += seconds
            if inactiveElapsed >= restThreshold { resetCycle() }
            return
        }
        inactiveElapsed = 0
        guard !paused else { return }
        elapsed += seconds
        snoozeRemaining = max(0, snoozeRemaining - seconds)
    }

    public mutating func markPresented() { presented = true }
    public mutating func snooze(seconds: Double = 600) {
        presented = false
        snoozeRemaining = seconds.isFinite ? max(1, seconds) : 600
    }
    public mutating func skip() { resetCycle(); inactiveElapsed = 0 }
    public mutating func completeRest() { skip() }
    private mutating func resetCycle() { elapsed = 0; snoozeRemaining = 0; presented = false }
}
