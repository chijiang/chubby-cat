import AppKit
import ChubbyCatCore

final class SpriteAtlas {
    static let shared = SpriteAtlas()
    let frames: [[NSImage]]
    let bitmaps: [[NSBitmapImageRep]]
    let master: NSImage
    var framePixelSize: Int { bitmaps[0][0].pixelsWide }

    private init() {
        let packaged = Bundle.main.resourceURL
        let root: URL
        if let packaged, FileManager.default.fileExists(atPath: packaged.appendingPathComponent("cat-atlas.png").path) { root = packaged }
        else { root = Bundle.module.resourceURL! }
        master = NSImage(contentsOf: root.appendingPathComponent("cat-master.png")) ?? NSImage(size: .init(width: 512, height: 512))
        let frameRoot = root.appendingPathComponent("cat-frames")
        if let data = try? Data(contentsOf: frameRoot.appendingPathComponent("index.json")),
           let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let names = manifest["frames"] as? [[String]], names.count == 6, names.allSatisfy({ $0.count == 6 }) {
            var images: [[NSImage]] = [], masks: [[NSBitmapImageRep]] = []
            for row in names {
                var imageRow: [NSImage] = [], bitmapRow: [NSBitmapImageRep] = []
                for name in row {
                    guard let image = NSImage(contentsOf: frameRoot.appendingPathComponent(name)),
                          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("Missing cat frame: \(name)") }
                    imageRow.append(image); bitmapRow.append(NSBitmapImageRep(cgImage: cg))
                }
                images.append(imageRow); masks.append(bitmapRow)
            }
            frames = images; bitmaps = masks; return
        }
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
    var action: CatAction = .idle {
        didSet {
            guard action != oldValue else { return }
            if !reducedMotion {
                outgoing = SpriteAtlas.shared.frames[oldValue.row][frameIndex]
                transitionElapsed = 0
            } else { outgoing = nil }
            playback.setAction(action); frameIndex = 0; needsDisplay = true
        }
    }
    var mirrored = false { didSet { if mirrored != oldValue { outgoing = nil; needsDisplay = true } } }
    var reducedMotion = false { didSet { if reducedMotion { outgoing = nil; frameIndex = 0 }; needsDisplay = true } }
    private(set) var frameIndex = 0
    private var playback = AnimationPlayback()
    private var outgoing: NSImage?
    private var transitionElapsed: Double = 0
    var travelDistance: Double?
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
        guard seconds.isFinite, seconds >= 0 else { return }
        guard !reducedMotion else {
            if frameIndex != 0 { frameIndex = 0; needsDisplay = true }
            return
        }
        playback.advance(by: seconds)
        let next = action == .walk && travelDistance != nil
            ? CatMotion.walkFrame(distance: travelDistance!, size: bounds.width)
            : playback.frameIndex
        if next != frameIndex { frameIndex = next; needsDisplay = true }
        if outgoing != nil {
            transitionElapsed += seconds; needsDisplay = true
            if transitionElapsed >= 0.16 { outgoing = nil }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.saveGraphicsState()
        if mirrored { let transform = NSAffineTransform(); transform.translateX(by: bounds.width, yBy: 0); transform.scaleX(by: -1, yBy: 1); transform.concat() }
        let amount = reducedMotion ? 1 : min(1, transitionElapsed / 0.16)
        if let outgoing { outgoing.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1 - amount) }
        let displayedAction: CatAction = reducedMotion ? .idle : action
        SpriteAtlas.shared.frames[displayedAction.row][frameIndex].draw(in: bounds, from: .zero, operation: .sourceOver, fraction: outgoing == nil ? 1 : amount)
        NSGraphicsContext.restoreGraphicsState()
    }
    func containsCat(_ local: NSPoint) -> Bool {
        guard bounds.contains(local), bounds.width > 0 else { return false }
        let pixels = SpriteAtlas.shared.framePixelSize
        let normalizedX = Int(local.x / bounds.width * Double(pixels))
        let x = mirrored ? pixels - 1 - normalizedX : normalizedX
        let y = pixels - 1 - Int(local.y / bounds.height * Double(pixels))
        guard (0..<pixels).contains(x), (0..<pixels).contains(y) else { return false }
        return (SpriteAtlas.shared.bitmaps[(reducedMotion ? CatAction.idle : action).row][reducedMotion ? 0 : frameIndex].colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2
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
    private var lastFrameTime = ProcessInfo.processInfo.systemUptime
    private var motionID = UUID()
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let delta = max(0, now - self.lastFrameTime); self.lastFrameTime = now
                guard self.enabled, self.isSystemActive, self.panel.isVisible else { return }
                self.sprite.step(delta)
                let local = NSPoint(x: NSEvent.mouseLocation.x - self.panel.frame.minX, y: NSEvent.mouseLocation.y - self.panel.frame.minY)
                self.panel.ignoresMouseEvents = !self.sprite.isDragging && !self.sprite.containsCat(local)
            }
        }
        timer?.tolerance = 0.005
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
        applyAnchoredFrame(CatMotion.scaledFrame(old, size: size))
        recoverPosition()
    }
    func cancelMotion() { motionID = UUID(); sprite.travelDistance = nil }
    func move(to target: NSPoint, speed: Double, reduced: Bool) async throws {
        try Task.checkCancellation()
        let start = panel.frame.origin
        let distance = hypot(target.x - start.x, target.y - start.y)
        guard distance > 0.5 else { return }
        let token = UUID(); motionID = token
        if !reduced { sprite.mirrored = target.x < start.x; sprite.travelDistance = 0; sprite.action = .walk }
        defer {
            if motionID == token {
                sprite.travelDistance = nil
                if sprite.action == .walk { sprite.action = .idle }
            }
        }
        let duration = reduced ? 0 : max(0.35, distance / max(1, speed))
        try await animate(duration: duration) { progress in
            guard self.motionID == token else { return }
            self.panel.setFrameOrigin(.init(x: start.x + (target.x - start.x) * progress, y: start.y + (target.y - start.y) * progress))
            self.sprite.travelDistance = distance * progress
        }
    }
    func scale(to size: Double, reduced: Bool) async throws {
        let initial = panel.frame
        try await animate(duration: reduced ? 0 : 0.45) { progress in
            let current = initial.width + (size - initial.width) * progress
            self.applyAnchoredFrame(CatMotion.scaledFrame(initial, size: current))
        }
    }
    private func applyAnchoredFrame(_ frame: CGRect) {
        // NSWindow floors fractional origins. Round explicitly so scale-in/out
        // cannot accumulate a one-point downward drift on each cycle.
        var rounded = frame
        rounded.origin = CGPoint(x: frame.minX.rounded(), y: frame.minY.rounded())
        panel.setFrame(rounded, display: true)
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
