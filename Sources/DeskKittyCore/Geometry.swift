import Foundation
import CoreGraphics

public enum Placement {
    public static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let size = CGSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
        return CGRect(x: max(visible.minX, min(frame.minX, visible.maxX - size.width)),
                      y: max(visible.minY, min(frame.minY, visible.maxY - size.height)), width: size.width, height: size.height)
    }
}
