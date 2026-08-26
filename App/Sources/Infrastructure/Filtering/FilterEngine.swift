import UIKit
import CoreImage
import Accelerate

// MARK: - Filter engine
final class FilterEngine {
    private let context: CIContext

    init() {
        // Use GPU when available, fallback to CPU
        context = CIContext(options: [.workingColorSpace: CIColorSpace.sRGB,
                                      .cacheIntermediates: false,
                                      .OutputColorSpace: CGColorSpaceCreateDeviceRGB()])
    }

    func apply(filter: CIFilter, to image: CIImage) -> CIImage {
        filter.setValue(image, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { return image }
        return output.cropped(to: image.extent)
    }

    // MARK: - Camera-style filters (photofilters equivalent)

    static func makeFilters() -> [WallpaperFilter] {
        [
            WallpaperFilter(id: "original", name: "Original", iconName: "photo", apply: { $0 }),
            WallpaperFilter(id: "clarendon", name: "Clarendon", iconName: "camera.filters", apply: clarendon()),
            WallpaperFilter(id: "hudson", name: "Hudson", iconName: "camera.filters", apply: hudson()),
            WallpaperFilter(id: "mayfair", name: "Mayfair", iconName: "camera.filters", apply: mayfair()),
            WallpaperFilter(id: "valencia", name: "Valencia", iconName: "camera.filters", apply: valencia()),
            WallpaperFilter(id: "gingham", name: "Gingham", iconName: "camera.filters", apply: gingham()),
            WallpaperFilter(id: "lark", name: "Lark", iconName: "camera.filters", apply: lark()),
            WallpaperFilter(id: "rise", name: "Rise", iconName: "sun.max", apply: rise()),
            WallpaperFilter(id: "ambience", name: "Ambience", iconName: "bolt.half.stroke", apply: ambience()),
            WallpaperFilter(id: "inkwell", name: "Inkwell", iconName: "moon", apply: inkwell()),
            WallpaperFilter(id: "hefe", name: "Hefe", iconName: "camera.aperture", apply: hefe()),
            WallpaperFilter(id: "lofi", name: "Lo-Fi", iconName: "waveform", apply: lofi()),
            WallpaperFilter(id: "earlybird", name: "Earlybird", iconName: "sunrise", apply: earlybird()),
            WallpaperFilter(id: "vintage", name: "Vintage", iconName: "clock.arrow.circlepath", apply: vintage()),
            WallpaperFilter(id: "sutro", name: "Sutro", iconName: "sparkles", apply: sutro()),
            WallpaperFilter(id: "walden", name: "Walden", iconName: "leaf", apply: walden()),
            WallpaperFilter(id: "normal", name: "Normal", iconName: "eye", apply: { image in
                // reduceContrast + slight saturation boost to normalize
                let reduce = CIFilter(name: "CIReduceContrast", parameters: [kCIInputImageKey: image, kCIInputContrastKey: 0.85])!
                let output = reduce.outputImage ?? image
                let saturation = CIFilter(name: "CIsaturation", parameters: [kCIInputImageKey: output, kCIInputSaturationKey: 1.1])!
                return saturation.outputImage?.cropped(to: image.extent) ?? image
            }),
            WallpaperFilter(id: "grayscale", name: "Mono", iconName: "circle.lefthalf.filled", apply: {
                let filter = CIFilter(name: "CIColorMonochrome", parameters: [
                    kCIInputImageKey: $0,
                    kCIInputColorKey: CIColor(red: 0.7, green: 0.7, blue: 0.7),
                    kCIInputIntensityKey: 1.0
                ])!
                return filter.outputImage?.cropped(to: $0.extent) ?? $0
            }),
        ]
    }

    // Clarendon: increase saturation, slight contrast, warm highlight
    private static func clarendon() -> @Sendable (CIImage) -> CIImage {
        { image in
            let contrast = CIFilter(name: "CIEqualizeHistogram", parameters: [kCIInputImageKey: image])!
            var result = contrast.outputImage ?? image
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: result, kCIInputSaturationKey: 1.2])!
            result = sat.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func hudson() -> @Sendable (CIImage) -> CIImage {
        // Hudson: reduce saturation, warm tint, contrast increase
        { image in
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: image, kCIInputSaturationKey: 0.7])!
            var result = sat.outputImage ?? image
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.85, blue: 0.6),
                kCIInputIntensityKey: 0.15
            ])!
            result = warm.outputImage ?? result
            let contrast = CIFilter(name: "CIContrast", parameters: [kCIInputImageKey: result, kCIInputContrastKey: 1.15])!
            result = contrast.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func mayfair() -> @Sendable (CIImage) -> CIImage {
        // Mayfair: warm, cream tone, vignette
        { image in
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: image,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.9, blue: 0.7),
                kCIInputIntensityKey: 0.25
            ])!
            var result = warm.outputImage ?? image
            // Vignette
            let vignette = CIFilter(name: "CIVignetteEffect", parameters: [
                kCIInputImageKey: result,
                kCIInputIntensityKey: 0.4,
                kCIInputRadiusKey: 1.0
            ])!
            result = vignette.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func valencia() -> @Sendable (CIImage) -> CIImage {
        // Valencia: warm highlights, slightly reduced shadows, saturation boost
        { image in
            let shadowReduce = CIFilter(name: "CIShadowHighlight", parameters: [
                kCIInputImageKey: image,
                kCIInputShadowAmountKey: 0.1,
                kCIInputHighlightAmountKey: 0.1
            ])!
            var result = shadowReduce.outputImage ?? image
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: result, kCIInputSaturationKey: 1.15])!
            result = sat.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func gingham() -> @Sendable (CIImage) -> CIImage {
        // Gingham: desaturate, cool highlights, slightly faded
        { image in
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: image, kCIInputSaturationKey: 0.5])!
            var result = sat.outputImage ?? image
            let cool = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 0.8, green: 0.85, blue: 0.9),
                kCIInputIntensityKey: 0.1
            ])!
            result = cool.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func lark() -> @Sendable (CIImage) -> CIImage {
        // Lark: brighten, boost shadows, warm
        { image in
            let brighten = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: image,
                kCIInputBrightnessKey: 0.1,
                kCIInputContrastKey: 1.05
            ])!
            var result = brighten.outputImage ?? image
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.92, blue: 0.8),
                kCIInputIntensityKey: 0.12
            ])!
            result = warm.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func rise() -> @Sendable (CIImage) -> CIImage {
        // Rise: warm orange tint, high contrast
        { image in
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: image,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.7, blue: 0.35),
                kCIInputIntensityKey: 0.35
            ])!
            var result = warm.outputImage ?? image
            let contrast = CIFilter(name: "CIContrast", parameters: [kCIInputImageKey: result, kCIInputContrastKey: 1.2])!
            result = contrast.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func ambience() -> @Sendable (CIImage) -> CIImage {
        // Ambience: blue tint, low contrast, soft
        { image in
            let soft = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: image, kCIInputRadiusKey: 0.5])!
            var result = soft.outputImage ?? image
            let blue = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 0.6, green: 0.7, blue: 1.0),
                kCIInputIntensityKey: 0.18
            ])!
            result = blue.outputImage ?? result
            let contrast = CIFilter(name: "CIContrast", parameters: [kCIInputImageKey: result, kCIInputContrastKey: 0.85])!
            result = contrast.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func inkwell() -> @Sendable (CIImage) -> CIImage {
        // Inkwell: black and white with high contrast
        { image in
            let bwc = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: image,
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])!
            var result = bwc.outputImage ?? image
            let contrast = CIFilter(name: "CIContrast", parameters: [kCIInputImageKey: result, kCIInputContrastKey: 1.3])!
            result = contrast.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func hefe() -> @Sendable (CIImage) -> CIImage {
        // Hefe: vignette + slight green tint + saturation
        { image in
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: image, kCIInputSaturationKey: 1.05])!
            var result = sat.outputImage ?? image
            let vignette = CIFilter(name: "CIVignetteEffect", parameters: [
                kCIInputImageKey: result,
                kCIInputIntensityKey: 0.3,
                kCIInputRadiusKey: 1.0
            ])!
            result = vignette.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func lofi() -> @Sendable (CIImage) -> CIImage {
        // Lo-Fi: faded, warm, slightly blurry
        { image in
            let fade = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: image,
                kCIInputBrightnessKey: 0.05,
                kCIInputContrastKey: 0.8,
                kCIInputSaturationKey: 0.7
            ])!
            var result = fade.outputImage ?? image
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.85, blue: 0.7),
                kCIInputIntensityKey: 0.15
            ])!
            result = warm.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func earlybird() -> @Sendable (CIImage) -> CIImage {
        // Earlybird: warm, saturated, slight vignette
        { image in
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: image, kCIInputSaturationKey: 1.2])!
            var result = sat.outputImage ?? image
            let warm = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 1.0, green: 0.87, blue: 0.72),
                kCIInputIntensityKey: 0.2
            ])!
            result = warm.outputImage ?? result
            let vignette = CIFilter(name: "CIVignetteEffect", parameters: [
                kCIInputImageKey: result,
                kCIInputIntensityKey: 0.25,
                kCIInputRadiusKey: 1.0
            ])!
            result = vignette.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func vintage() -> @Sendable (CIImage) -> CIImage {
        // Vintage: faded sepia
        { image in
            let sepia = CIFilter(name: "CISepiaTone", parameters: [kCIInputImageKey: image, kCIInputIntensityKey: 0.4])!
            var result = sepia.outputImage ?? image
            let fade = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: result,
                kCIInputContrastKey: 0.85,
                kCIInputBrightnessKey: 0.05
            ])!
            result = fade.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func sutro() -> @Sendable (CIImage) -> CIImage {
        // Sutro: high contrast, blue/purple tint, dark
        { image in
            let contrast = CIFilter(name: "CIContrast", parameters: [kCIInputImageKey: image, kCIInputContrastKey: 1.4])!
            var result = contrast.outputImage ?? image
            let tint = CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputImageKey: result,
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.9),
                kCIInputIntensityKey: 0.25
            ])!
            result = tint.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }

    private static func walden() -> @Sendable (CIImage) -> CIImage {
        // Walden: bright, high saturation, warm
        { image in
            let sat = CIFilter(name: "CISaturate", parameters: [kCIInputImageKey: image, kCIInputSaturationKey: 1.4])!
            var result = sat.outputImage ?? image
            let bright = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: result,
                kCIInputBrightnessKey: 0.1,
                kCIInputContrastKey: 1.05
            ])!
            result = bright.outputImage ?? result
            return result.cropped(to: image.extent)
        }
    }
}
