import AppKit
import ChubbyCatCore

enum CatAction: String, CaseIterable, Identifiable {
    case idle, walk, stretch, think, talk, sleep
    var id: String { rawValue }
    var label: String { ["idle": "Relax", "walk": "Walk", "stretch": "Stretch", "think": "Think", "talk": "Chat", "sleep": "Nap"][rawValue]! }
    var row: Int { Self.allCases.firstIndex(of: self)! }
    var durations: [Double] {
        switch self {
        case .idle: return [1.8, 0.12, 0.1, 0.12, 0.4, 1.46]
        case .walk: return Array(repeating: 0.125, count: 6)
        case .stretch: return [0.16, 0.18, 0.24, 0.35, 0.2, 0.18]
        case .think: return Array(repeating: 0.25, count: 6)
        case .talk: return Array(repeating: 0.14, count: 6)
        case .sleep: return Array(repeating: 0.5, count: 6)
        }
    }
}

final class SpriteAtlas {
    static let shared = SpriteAtlas()
    let frames: [[NSImage]]
    let bitmaps: [[NSBitmapImageRep]]
    let master: NSImage

    private init() {
        let packaged = Bundle.main.resourceURL
        let root: URL
        if let packaged, FileManager.default.fileExists(atPath: packaged.appendingPathComponent("cat-atlas.png").path) { root = packaged }
        else { root = Bundle.module.resourceURL! }
        master = NSImage(contentsOf: root.appendingPathComponent("cat-master.png")) ?? NSImage(size: .init(width: 512, height: 512))
        guard let source = NSImage(contentsOf: root.appendingPathComponent("cat-atlas.png")),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("Bundled cat artwork is missing.") }
        // Hand-mapped design regions: the source sheet is not an evenly spaced atlas.
        let xs = [0, 233, 438, 642, 844, 1048, 1254]
        let ys = [0, 240, 419, 624, 852, 1091, 1254]
        var rows: [[NSImage]] = []
        var masks: [[NSBitmapImageRep]] = []
        for row in 0..<6 {
            var images: [NSImage] = []
            var rowMasks: [NSBitmapImageRep] = []
            for col in 0..<6 {
                let region = CGRect(x: xs[col], y: ys[row], width: xs[col + 1] - xs[col], height: ys[row + 1] - ys[row])
                let crop = cg.cropping(to: region)!
                let width = crop.width, height = crop.height
                let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
                let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
                var left = width, right = 0, top = height, bottom = 0
                for y in 0..<height {
                    for x in 0..<width {
                        let offset = (y * width + x) * 4
                        if bytes[offset + 3] < 40 {
                            bytes[offset] = 0; bytes[offset + 1] = 0; bytes[offset + 2] = 0; bytes[offset + 3] = 0
                        }
                        if bytes[offset + 3] > 160 { left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y) }
                    }
                }
                let trimmed = context.makeImage()!.cropping(to: CGRect(x: max(0, left - 2), y: max(0, top - 2), width: min(width - max(0, left - 2), right - left + 5), height: min(height - max(0, top - 2), bottom - top + 5)))!
                let canvas = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 2048,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                let scale = 1.85
                let target = CGRect(x: (512 - Double(trimmed.width) * scale) / 2, y: 55,
                                    width: Double(trimmed.width) * scale, height: Double(trimmed.height) * scale)
                canvas.interpolationQuality = .high
                canvas.draw(trimmed, in: target)
                let image = canvas.makeImage()!
                images.append(NSImage(cgImage: image, size: NSSize(width: 512, height: 512)))
                rowMasks.append(NSBitmapImageRep(cgImage: image))
            }
            rows.append(images); masks.append(rowMasks)
        }
        frames = rows; bitmaps = masks
    }
}

final class PetSpriteView: NSView {
    var action: CatAction = .idle { didSet { if action != oldValue { frameIndex = 0; elapsed = 0; needsDisplay = true } } }
    var mirrored = false { didSet { needsDisplay = true } }
    var reducedMotion = false
    var frameIndex = 0
    private var elapsed: Double = 0
    var onClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var contextMenu: (() -> NSMenu)?
    private var mouseStart: NSPoint = .zero
    private var windowStart: NSPoint = .zero
    private var dragging = false
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func step(_ seconds: Double) {
        guard !reducedMotion else { if frameIndex != 0 { frameIndex = 0; needsDisplay = true }; return }
        elapsed += seconds
        let durations = action.durations
        if elapsed >= durations[frameIndex] {
            elapsed = 0
            frameIndex = action == .stretch ? min(5, frameIndex + 1) : (frameIndex + 1) % 6
            needsDisplay = true
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.saveGraphicsState()
        if mirrored { let transform = NSAffineTransform(); transform.translateX(by: bounds.width, yBy: 0); transform.scaleX(by: -1, yBy: 1); transform.concat() }
        SpriteAtlas.shared.frames[action.row][frameIndex].draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()
    }
    func containsCat(_ local: NSPoint) -> Bool {
        guard bounds.contains(local), bounds.width > 0 else { return false }
        let normalizedX = Int(local.x / bounds.width * 512)
        let x = mirrored ? 511 - normalizedX : normalizedX
        let y = 511 - Int(local.y / bounds.height * 512)
        guard (0..<512).contains(x), (0..<512).contains(y) else { return false }
        return (SpriteAtlas.shared.bitmaps[action.row][frameIndex].colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2
    }
    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
        dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        if !dragging && hypot(mouse.x - mouseStart.x, mouse.y - mouseStart.y) > 3 { dragging = true; onDragStart?(); action = .idle }
        guard dragging else { return }
        window?.setFrameOrigin(NSPoint(x: windowStart.x + mouse.x - mouseStart.x, y: windowStart.y + mouse.y - mouseStart.y))
    }
    override func mouseUp(with event: NSEvent) { if dragging { dragging = false; onDragEnd?() } else { onClick?() } }
    override func rightMouseDown(with event: NSEvent) { if let menu = contextMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } }
    var isDragging: Bool { dragging }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PetWindowController {
    let panel: PetPanel
    let sprite = PetSpriteView(frame: .zero)
    private var timer: Timer?
    var enabled = true
    var isSystemActive = true
    var normalSize: Double = 190
    var onPositionSaved: ((NSPoint) -> Void)?

    init() {
        panel = PetPanel(contentRect: .init(x: 0, y: 0, width: 190, height: 190), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = sprite
        sprite.autoresizingMask = [.width, .height]
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.enabled, self.isSystemActive, self.panel.isVisible else { return }
                self.sprite.step(1.0 / 12)
                let local = NSPoint(x: NSEvent.mouseLocation.x - self.panel.frame.minX, y: NSEvent.mouseLocation.y - self.panel.frame.minY)
                self.panel.ignoresMouseEvents = !self.sprite.isDragging && !self.sprite.containsCat(local)
            }
        }
        timer?.tolerance = 0.02
    }
    var screen: NSScreen { panel.screen ?? NSScreen.main ?? NSScreen.screens[0] }
    func show(at position: NSPoint? = nil) {
        enabled = true
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = position ?? NSPoint(x: screen.visibleFrame.maxX - normalSize - 50, y: screen.visibleFrame.minY + 35)
        panel.setFrame(.init(origin: origin, size: .init(width: normalSize, height: normalSize)), display: true)
        recoverPosition(); panel.orderFrontRegardless()
    }
    func hide() { enabled = false; panel.orderOut(nil) }
    func recoverPosition() {
        let target = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(Placement.clamp(panel.frame, to: target.visibleFrame), display: true)
    }
    func resize(to size: Double) {
        normalSize = size
        let old = panel.frame
        panel.setFrame(NSRect(x: old.midX - size / 2, y: old.minY, width: size, height: size), display: true)
        recoverPosition()
    }
    func move(to target: NSPoint, speed: Double, reduced: Bool) async throws {
        let start = panel.frame.origin
        let distance = hypot(target.x - start.x, target.y - start.y)
        sprite.mirrored = target.x < start.x; sprite.action = .walk
        let duration = reduced ? 0 : max(0.35, distance / speed)
        try await animate(duration: duration) { progress in
            self.panel.setFrameOrigin(.init(x: start.x + (target.x - start.x) * progress, y: start.y + (target.y - start.y) * progress))
        }
        sprite.action = .idle
    }
    func scale(to size: Double, reduced: Bool) async throws {
        let initial = panel.frame
        try await animate(duration: reduced ? 0 : 0.45) { progress in
            let current = initial.width + (size - initial.width) * progress
            self.panel.setFrame(.init(x: initial.midX - current / 2, y: initial.minY + (initial.height - current) * 0.11, width: current, height: current), display: true)
        }
    }
    private func animate(duration: Double, update: @escaping (Double) -> Void) async throws {
        guard duration > 0 else { try Task.checkCancellation(); update(1); return }
        let start = ProcessInfo.processInfo.systemUptime
        while true {
            try Task.checkCancellation()
            let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / duration)
            update(t * t * (3 - 2 * t))
            if t >= 1 { return }
            try await Task.sleep(nanoseconds: 16_666_667)
        }
    }
}
