import Foundation
import DeskKittyCore

final class GeometryTests {
    func testDisconnectedMonitorPositionClampsToVisibleScreen() {
        let screen = CGRect(x: 0, y: 40, width: 1440, height: 840)
        let corrected = Placement.clamp(CGRect(x: -2000, y: 1200, width: 200, height: 200), to: screen)
        expectEqual(corrected, CGRect(x: 0, y: 680, width: 200, height: 200))
    }

    func testOversizedWindowFitsAndNegativeDisplayCoordinatesRemainValid() {
        expectEqual(Placement.clamp(CGRect(x: 0, y: 0, width: 2000, height: 2000), to: CGRect(x: -1000, y: 0, width: 1000, height: 700)), CGRect(x: -1000, y: 0, width: 1000, height: 700))
    }
}
