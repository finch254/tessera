import UIKit
import CoreImage
import CoreGraphics

// MARK: - Palette extraction (quantized dominant colors)
actor PaletteExtractor {
    /// Extract up to `maximumColorCount` dominant colors from a UIImage
    func extract(from image: UIImage, maximumColorCount: Int = 6) -> [PaletteColor] {
        guard let cgImage = image.cgImage else { return [] }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawPointer: UnsafeMutableRawPointer?

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cgImage.width
        let totalBytes = bytesPerRow * cgImage.height

        rawPointer = malloc(totalBytes)
        guard let pixelData = rawPointer else { return [] }

        defer { free(pixelData) }

        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(data: pixelData,
                                       width: cgImage.width,
                                       height: cgImage.height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let data = UnsafeMutableBufferPointer<UInt8>(start: pixelData.assumingMemoryBound(to: UInt8.self), count: totalBytes)

        // Quantize to get dominant colors using simple median-cut style sampling
        let pixelCount = cgImage.width * cgImage.height
        let sampledColors = sampleColors(
            from: data,
            width: cgImage.width,
            height: cgImage.height,
            sampleCount: min(200, max(1, pixelCount / 50))
        )

        let quantized = quantize(sampledColors, buckets: maximumColorCount)
            .sorted { $0.count > $1.count }

        return quantized.map { PaletteColor(color: UIColor(red: CGFloat($0.r) / 255.0,
                                                       green: CGFloat($0.g) / 255.0,
                                                       blue: CGFloat($0.b) / 255.0,
                                                       alpha: 1.0),
                                            population: $0.count) }
    }

    private func sampleColors(from data: UnsafeMutableBufferPointer<UInt8>,
                              width: Int, height: Int,
                              sampleCount: Int) -> [(r: Int, g: Int, b: Int)] {
        var colors: [(r: Int, g: Int, b: Int)] = []
        let step = max(1, (width * height) / sampleCount)

        for i in stride(from: 0, to: width * height, by: step) {
            let offset = i * 4
            let r = Int(data[offset])
            let g = Int(data[offset + 1])
            let b = Int(data[offset + 2])
            if r < 25 && g < 25 && b < 25 { continue } // skip near-black (often UI)
            colors.append((r, g, b))
        }
        return colors
    }

    private func quantize(_ colors: [(r: Int, g: Int, b: Int)], buckets: Int) -> [(r: Int, g: Int, b: Int, count: Int)] {
        guard !colors.isEmpty else { return [] }
        guard buckets > 0 else { return [] }

        // Simple k-means-like quantization with 3 iterations
        var centroids: [(r: Int, g: Int, b: Int)] = []

        // Initialize with evenly spaced colors
        let step = max(1, colors.count / buckets)
        for i in 0..<buckets {
            let idx = min(i * step, colors.count - 1)
            centroids.append(colors[idx])
        }

        for _ in 0..<3 {
            var clusters: [(centroidIdx: Int, colors: [(r: Int, g: Int, b: Int)])] = Array(repeating: (0, []), count: buckets)

            for color in colors {
                var bestIdx = 0
                var bestDist = Double.infinity
                for (idx, centroid) in centroids.enumerated() {
                    let dr = Double(color.r - centroid.r)
                    let dg = Double(color.g - centroid.g)
                    let db = Double(color.b - centroid.b)
                    let dist = dr * dr + dg * dg + db * db
                    if dist < bestDist {
                        bestDist = dist
                        bestIdx = idx
                    }
                }
                clusters[bestIdx].colors.append(color)
            }

            for (idx, cluster) in clusters.enumerated() {
                guard !cluster.colors.isEmpty else { continue }
                let sumR = cluster.colors.reduce(0) { $0 + $1.r }
                let sumG = cluster.colors.reduce(0) { $0 + $1.g }
                let sumB = cluster.colors.reduce(0) { $0 + $1.b }
                let count = cluster.colors.count
                centroids[idx] = (r: sumR / count, g: sumG / count, b: sumB / count)
            }
        }

        // Final assignment for counts
        var finalClusters: [(r: Int, g: Int, b: Int, count: Int)] = Array(repeating: (0, 0, 0, 0), count: buckets)
        for color in colors {
            var bestIdx = 0
            var bestDist = Double.infinity
            for (idx, centroid) in centroids.enumerated() {
                let dr = Double(color.r - centroid.r)
                let dg = Double(color.g - centroid.g)
                let db = Double(color.b - centroid.b)
                let dist = dr * dr + dg * dg + db * db
                if dist < bestDist {
                    bestDist = dist
                    bestIdx = idx
                }
            }
            finalClusters[bestIdx].r = centroids[bestIdx].r
            finalClusters[bestIdx].g = centroids[bestIdx].g
            finalClusters[bestIdx].b = centroids[bestIdx].b
            finalClusters[bestIdx].count += 1
        }

        return finalClusters.filter { $0.count > 0 }
    }
}
