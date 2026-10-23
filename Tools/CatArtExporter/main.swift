import AppKit
import ImageIO
import UniformTypeIdentifiers
import ChubbyCatCore

struct Pose {
    let image: CGImage
    let bounds: CGRect
    let centerX: Double
    let bodyHeight: Double
}
func cleanedPose(_ image: CGImage) -> Pose {
    let w = image.width, h = image.height
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let raw = context.data!.assumingMemoryBound(to: UInt8.self)
    let pixels = SpritePixels.cleaned(Array(UnsafeBufferPointer(start: raw, count: w * h * 4)), width: w, height: h)
    pixels.withUnsafeBytes { context.data!.copyMemory(from: $0.baseAddress!, byteCount: pixels.count) }
    var left = w, right = 0, bottom = h, top = 0
    var mass = 0.0, weightedX = 0.0
    for y in 0..<h { for x in 0..<w {
        let alpha = Int(pixels[(y * w + x) * 4 + 3])
        if alpha > 64 {
            left = min(left, x); right = max(right, x); bottom = min(bottom, y); top = max(top, y)
            mass += Double(alpha); weightedX += Double(x * alpha)
        }
    } }
    precondition(left < right && bottom < top, "Empty pose")
    let centerX = weightedX / mass
    var headTop = h
    for y in 0..<h { for x in max(0, Int(centerX))..<w where pixels[(y * w + x) * 4 + 3] > 64 { headTop = min(headTop, y) } }
    return Pose(image: context.makeImage()!, bounds: CGRect(x: left, y: bottom, width: right - left + 1, height: top - bottom + 1), centerX: centerX, bodyHeight: Double(top - headTop + 1))
}
func png(_ image: CGImage, to path: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: path)
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourcePath = root.appendingPathComponent("assets/cat/animation-keyframes-v3.png")
let source = NSImage(contentsOf: sourcePath)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let xs = [0, 233, 438, 642, 844, 1048, 1254], ys = [0, 240, 419, 624, 852, 1091, 1254]
var poses: [[Pose]] = (0..<6).map { row in (0..<6).map { col in
    cleanedPose(source.cropping(to: CGRect(x: xs[col], y: ys[row], width: xs[col + 1] - xs[col], height: ys[row + 1] - ys[row]))!)
} }
let size = 768
let maxWidth = poses.flatMap { $0 }.map { $0.bounds.width }.max()!
let maxHeight = poses.flatMap { $0 }.map { $0.bounds.height }.max()!
let baseScale = min(Double(size) * 0.88 / maxWidth, Double(size) * 0.76 / maxHeight)
var rowScales = Array(repeating: baseScale, count: 6)
var sourceNote = "legacy v3, cleaned and aligned; native pose detail approx 200px"
if CommandLine.arguments.count > 1 {
    let walk = NSImage(contentsOfFile: CommandLine.arguments[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let oldHeight = poses[1].map { $0.bounds.height }.max()!
    let w = walk.width / 3, h = walk.height / 2
    poses[1] = (0..<6).map { i in cleanedPose(walk.cropping(to: CGRect(x: (i % 3) * w, y: (i / 3) * h, width: w, height: h))!) }
    // The new cat carries its tail upright; use ear-to-ground height rather
    // than tail height so its body does not shrink when switching to walking.
    rowScales[1] = baseScale * oldHeight / poses[1].map { $0.bodyHeight }.max()!
    sourceNote += "; walk uses \(CommandLine.arguments[1]) at \(walk.width)x\(walk.height)"
}
let output = root.appendingPathComponent("Sources/ChubbyCat/Resources/cat-frames")
let preview = root.appendingPathComponent("docs/images/animation")
try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try! FileManager.default.createDirectory(at: preview, withIntermediateDirectories: true)
var frameNames: [[String]] = []
let contact = CGContext(data: nil, width: size * 6, height: size * 6, bitsPerComponent: 8, bytesPerRow: size * 6 * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
for action in CatAction.allCases {
    var images: [CGImage] = [], names: [String] = []
    for col in 0..<6 {
        let pose = poses[action.row][col], scale = rowScales[action.row]
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // CGContext uses bottom-up coordinates. Common alpha-weighted torso center and foot baseline.
        let rect = CGRect(x: Double(size) / 2 - pose.centerX * scale,
                          y: Double(size) * CatMotion.footAnchor - (Double(pose.image.height) - pose.bounds.maxY) * scale,
                          width: Double(pose.image.width) * scale, height: Double(pose.image.height) * scale)
        context.interpolationQuality = .high; context.draw(pose.image, in: rect)
        let image = context.makeImage()!
        let name = "\(action.rawValue)-\(col + 1).png"
        png(image, to: output.appendingPathComponent(name)); names.append(name); images.append(image)
        contact.draw(image, in: CGRect(x: col * size, y: (5 - action.row) * size, width: size, height: size))
    }
    frameNames.append(names)
    let url = preview.appendingPathComponent("\(action.rawValue).gif")
    let gif = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 6, nil)!
    CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for (i, image) in images.enumerated() {
        CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: action.durations[i], kCGImagePropertyGIFUnclampedDelayTime: action.durations[i]]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(gif))
}
png(contact.makeImage()!, to: preview.appendingPathComponent("contact-sheet.png"))
let metadata: [String: Any] = ["version": 1, "frameSize": size, "anchor": [0.5, CatMotion.footAnchor], "frames": frameNames, "source": sourceNote]
try! JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("index.json"))
print("Exported 36 aligned \(size)px frames, 6 GIF previews and contact sheet. \(sourceNote)")
