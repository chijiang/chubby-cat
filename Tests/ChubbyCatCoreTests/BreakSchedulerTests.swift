import Foundation
import ChubbyCatCore

final class BreakSchedulerTests {
    func testNinetyMinuteBoundaryAndPresentationIsOneShot() {
        var clock = BreakScheduler()
        clock.advance(by: 5399, active: true)
        expectFalse(clock.shouldRemind)
        clock.advance(by: 1, active: true)
        expectTrue(clock.shouldRemind)
        clock.markPresented()
        clock.advance(by: 30, active: true)
        expectFalse(clock.shouldRemind)
    }

    func testSnoozeKeepsElapsedAndUsesOnlyActiveTime() {
        var clock = BreakScheduler(elapsed: 5400)
        clock.markPresented()
        clock.snooze(seconds: 600)
        clock.advance(by: 200, active: true)
        clock.advance(by: 120, active: false)
        expectEqual(clock.elapsed, 5600)
        expectFalse(clock.shouldRemind)
        clock.advance(by: 400, active: true)
        expectTrue(clock.shouldRemind)
    }

    func testShortBreakResumesAndFiveMinuteBreakResets() {
        var clock = BreakScheduler(elapsed: 4000)
        clock.advance(by: 299, active: false)
        clock.advance(by: 1, active: true)
        expectEqual(clock.elapsed, 4001)
        clock.advance(by: 300, active: false)
        expectEqual(clock.elapsed, 0)
        clock.advance(by: 10, active: true)
        expectEqual(clock.elapsed, 10)
    }

    func testManualPauseDoesNotCountAsRest() {
        var clock = BreakScheduler(elapsed: 3200)
        clock.advance(by: 1000, active: true, paused: true)
        expectEqual(clock.elapsed, 3200)
        expectFalse(clock.shouldRemind)
    }

    func testSkipAndRestBothResetButInvalidDeltasDoNotChangeTime() {
        var clock = BreakScheduler(elapsed: 5400)
        clock.advance(by: -.infinity, active: true)
        clock.advance(by: .nan, active: true)
        expectEqual(clock.elapsed, 5400)
        clock.skip()
        expectEqual(clock.elapsed, 0)
        clock.advance(by: 200, active: true)
        clock.completeRest()
        expectEqual(clock.elapsed, 0)
    }

    func testCheckpointRestoresElapsedButNotPresentedOrInactiveGap() throws {
        var clock = BreakScheduler(elapsed: 5500)
        clock.markPresented()
        let data = try JSONEncoder().encode(clock.checkpoint)
        let restored = BreakScheduler(checkpoint: try JSONDecoder().decode(BreakCheckpoint.self, from: data))
        expectEqual(restored.elapsed, 5500)
        expectTrue(restored.shouldRemind)
    }
}
