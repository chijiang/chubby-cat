import Foundation

/// Operates on premultiplied RGBA, retaining white fur and natural pink features.
public enum SpritePixels {
    public static func cleaned(_ source: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              source.count == width * height * 4 else { return [] }
        var pixels = source
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]), g = Double(pixels[index + 1]), b = Double(pixels[index + 2])
            let redDebris = r > 80 && r > g * 2 && r > b * 1.7
            let yellowDebris = r > 100 && g > 80 && b < min(r, g) * 0.22
            if pixels[index + 3] < 32 || redDebris || yellowDebris {
                pixels[index] = 0; pixels[index + 1] = 0; pixels[index + 2] = 0; pixels[index + 3] = 0
            }
        }
        // Keep the silhouette and nearby whiskers; remove detached tiny islands.
        var seen = Array(repeating: false, count: width * height)
        var components: [[Int]] = []
        for seed in 0..<(width * height) where !seen[seed] && pixels[seed * 4 + 3] > 0 {
            var queue = [seed]; seen[seed] = true
            var cursor = 0
            while cursor < queue.count {
                let at = queue[cursor]; cursor += 1
                let x = at % width, y = at / width
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let next = ny * width + nx
                    if !seen[next] && pixels[next * 4 + 3] > 0 { seen[next] = true; queue.append(next) }
                } }
            }
            components.append(queue)
        }
        guard let largest = components.max(by: { $0.count < $1.count }) else { return pixels }
        let left = largest.map { $0 % width }.min()!, right = largest.map { $0 % width }.max()!
        let top = largest.map { $0 / width }.min()!, bottom = largest.map { $0 / width }.max()!
        let margin = max(2, width / 30)
        for component in components where component.count < largest.count {
            let nearBody = component.contains { let x = $0 % width, y = $0 / width
                return x >= left - margin && x <= right + margin && y >= top - margin && y <= bottom + margin
            }
            if !nearBody || component.count < 2 {
                for at in component { for channel in 0..<4 { pixels[at * 4 + channel] = 0 } }
            }
        }
        return pixels
    }
}
