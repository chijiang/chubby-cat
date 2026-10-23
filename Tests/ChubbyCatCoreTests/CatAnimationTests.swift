import Foundation
import ChubbyCatCore

final class CatAnimationTests {
    func testArtworkCleaningKeepsWhiteFurAndRemovesColoredDebris() {
        var pixels = Array(repeating: UInt8(0), count: 6 * 6 * 4)
        func put(_ x: Int, _ y: Int, _ rgba: [UInt8]) { pixels.replaceSubrange(((y * 6 + x) * 4)..<((y * 6 + x) * 4 + 4), with: rgba) }
        for y in 2...4 { for x in 2...4 { put(x, y, [245, 240, 232, 255]) } }
        put(3, 3, [200, 130, 120, 255])
        put(0, 0, [255, 0, 0, 255]); put(5, 0, [255, 240, 0, 255])
        let cleaned = SpritePixels.cleaned(pixels, width: 6, height: 6)
        expectEqual(cleaned[3], 0)
        expectEqual(cleaned[(5 * 4) + 3], 0)
        expectEqual(Array(cleaned[(3 * 6 + 3) * 4..<(3 * 6 + 3) * 4 + 4]), [200, 130, 120, 255])
        expectEqual(cleaned[(2 * 6 + 2) * 4 + 3], 255)
        expectEqual(SpritePixels.cleaned([], width: 6, height: 6), [])
    }
    func testTimingRetainsRemainderAndCatchesUp() {
        var a = AnimationPlayback(action: .talk)
        var b = AnimationPlayback(action: .talk)
        a.advance(by: 0.49)
        for _ in 0..<7 { b.advance(by: 0.07) }
        expectEqual(a.frameIndex, b.frameIndex)
        expectEqual(a.frameIndex, 3)
        a.advance(by: .nan); a.advance(by: -.infinity); a.advance(by: -3)
        expectEqual(a.frameIndex, 3)
        a.advance(by: 100_000)
        expectTrue((0..<6).contains(a.frameIndex))
    }
    func testOneShotAndActionReset() {
        var player = AnimationPlayback(action: .stretch)
        player.advance(by: 8)
        expectEqual(player.frameIndex, 5)
        expectTrue(player.completed)
        player.setAction(.idle)
        expectEqual(player.frameIndex, 0)
        expectFalse(player.completed)
        player.advance(by: 1)
        player.setAction(.idle)
        player.advance(by: 1)
        expectTrue(player.elapsed >= 2)
    }
    func testWalkingFollowsDistanceRatherThanTime() {
        expectEqual(CatMotion.walkFrame(distance: 0, size: 200), 0)
        expectEqual(CatMotion.walkFrame(distance: 36, size: 200), 1)
        expectEqual(CatMotion.walkFrame(distance: 108, size: 200), 4)
        expectEqual(CatMotion.walkFrame(distance: 144, size: 200), 0)
        expectEqual(CatMotion.walkFrame(distance: .nan, size: 0), 0)
        let start = CGRect(x: -300, y: 25, width: 200, height: 200)
        let enlarged = CatMotion.scaledFrame(start, size: 360)
        expectTrue(abs(enlarged.midX - start.midX) < 0.0001)
        expectTrue(abs(enlarged.minY + 360 * 0.12 - (start.minY + 200 * 0.12)) < 0.0001)
    }
    func testAmbientHasQuietGapsAndNeverOverwritesAnInteraction() {
        var cat = AmbientBehavior()
        expectEqual(cat.advance(by: 19, enabled: true), .idle)
        expectEqual(cat.advance(by: 1, enabled: true), .think)
        expectEqual(cat.advance(by: 3, enabled: true), .idle)
        expectEqual(cat.advance(by: 37, enabled: true), .stretch)
        expectEqual(cat.advance(by: 2, enabled: true), .stretch)
        expectEqual(cat.advance(by: 2, enabled: true), .idle)
        expectEqual(cat.advance(by: 116, enabled: true), .sleep)
        expectNil(cat.advance(by: 100, enabled: false))
        expectEqual(cat.advance(by: 1, enabled: true), .idle)
        expectEqual(cat.advance(by: .infinity, enabled: true), .idle)
    }
}
