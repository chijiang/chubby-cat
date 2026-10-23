import Foundation

public enum CatAction: String, CaseIterable, Identifiable, Codable {
    case idle, walk, stretch, think, talk, sleep
    public var id: String { rawValue }
    public var label: String { ["idle": "Relax", "walk": "Walk", "stretch": "Stretch", "think": "Think", "talk": "Chat", "sleep": "Nap"][rawValue]! }
    public var row: Int { Self.allCases.firstIndex(of: self)! }
    public var durations: [Double] {
        switch self {
        case .idle: return [3.6, 0.10, 0.09, 0.12, 0.7, 1.4]
        case .walk: return Array(repeating: 0.125, count: 6)
        case .stretch: return [0.22, 0.28, 0.32, 0.65, 0.3, 0.24]
        case .think: return [0.7, 0.35, 0.6, 0.45, 0.12, 0.8]
        case .talk: return [0.14, 0.14, 0.14, 0.14, 0.45, 0.65]
        case .sleep: return [0.8, 0.8, 0.8, 0.8, 0.8, 0.8]
        }
    }
}

/// Absolute clip time preserves the fractional remainder even after late callbacks.
public struct AnimationPlayback {
    public private(set) var action: CatAction
    public private(set) var elapsed: Double = 0
    public init(action: CatAction = .idle) { self.action = action }
    public mutating func setAction(_ action: CatAction) {
        guard action != self.action else { return }
        self.action = action; elapsed = 0
    }
    public mutating func advance(by seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        elapsed = min(elapsed + seconds, 1e12)
    }
    public var completed: Bool { action == .stretch && elapsed >= action.durations.reduce(0, +) }
    public var frameIndex: Int {
        let durations = action.durations
        let total = durations.reduce(0, +)
        if completed { return durations.count - 1 }
        var time = action == .stretch ? elapsed : elapsed.truncatingRemainder(dividingBy: total)
        for (index, duration) in durations.enumerated() {
            if time + 1e-9 < duration { return index }
            time -= duration
        }
        return 0
    }
}

public enum CatMotion {
    public static let footAnchor: Double = 0.12 // AppKit: measured up from bottom.
    public static func walkFrame(distance: Double, size: Double) -> Int {
        guard distance.isFinite, size.isFinite, size > 0, distance >= 0 else { return 0 }
        let phase = (distance / (size * 0.72)).truncatingRemainder(dividingBy: 1)
        return min(5, Int(phase * 6))
    }
    public static func scaledFrame(_ frame: CGRect, size: Double) -> CGRect {
        CGRect(x: frame.midX - size / 2,
               y: frame.minY + (frame.height - size) * footAnchor, width: size, height: size)
    }
}

/// Ambient poses never move the window or affect the break scheduler.
public struct AmbientBehavior {
    private var age: Double = 0
    public init() {}
    public mutating func reset() { age = 0 }
    public mutating func advance(by seconds: Double, enabled: Bool) -> CatAction? {
        guard enabled else { reset(); return nil }
        if seconds.isFinite, seconds > 0 { age += seconds }
        if age >= 220 { age = age.truncatingRemainder(dividingBy: 220) }
        switch age {
        case 20..<23, 95..<98, 140..<143: return .think
        // Leave enough time for the one-shot clip despite the 1 Hz behavior tick.
        case 60..<64: return .stretch
        case 180..<220: return .sleep
        default: return .idle
        }
    }
}
