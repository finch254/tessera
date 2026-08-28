import AVFoundation
import CoreImage
import Foundation
import UIKit

// MARK: - Errors
enum DescriptorError: Error, LocalizedError {
    case noVideoTrack
    case frameReadFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The video has no video track."
        case .frameReadFailed: return "Could not read video frames."
        case .writeFailed(let m): return "Failed to write descriptor: \(m)"
        }
    }
}

// MARK: - PosterBoard descriptor builder
/// Builds a PosterBoard wallpaper descriptor folder from a video. The result is
/// a directory tree PosterBoard's WallpaperKit CollectionsPoster extension can
/// load: a CAML animation whose keyframes are the video's frames, plus the
/// provider metadata files. Adapted from Pocket Poster's VideoHandler.
enum PosterDescriptorBuilder {

    /// Logical screen class used in the descriptor file names.
    private static let screenClass = "810w-1080h@2x~ipad"

    /// Build a video descriptor folder. Returns the descriptor root directory.
    /// - Parameters:
    ///   - videoURL: source video file.
    ///   - autoReverses: play the animation forwards then backwards.
    ///   - progress: called with (frameIndex, totalFramesEstimate).
    static func buildVideoDescriptor(from videoURL: URL,
                                     autoReverses: Bool = false,
                                     progress: ((Int, Int) -> Void)? = nil) throws -> URL {
        let fm = FileManager.default
        let descrURL = SymHandler.getDocumentsDirectory()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: descrURL, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: videoURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw DescriptorError.noVideoTrack
        }

        let preferredTransform = track.preferredTransform
        let size = track.naturalSize.applying(preferredTransform)
        let width = Int(abs(size.width))
        let height = Int(abs(size.height))
        let fps = track.nominalFrameRate
        let duration = CMTimeGetSeconds(asset.duration)
        let totalFrames = max(1, Int(fps * Float(duration)))
        let animDur = Double(totalFrames) / Double(max(fps, 1))

        // Folder layout -----------------------------------------------------
        let wallpaperName = "9183.Custom-\(screenClass).wallpaper"
        let backgroundCA = "9183.Custom_Background-\(screenClass).ca"
        let floatingCA = "9183.Custom_Floating-\(screenClass).ca"

        let contentsDir = descrURL
            .appendingPathComponent("versions/1/contents", isDirectory: true)
        let wallpaperDir = contentsDir.appendingPathComponent(wallpaperName, isDirectory: true)
        let backgroundDir = wallpaperDir.appendingPathComponent(backgroundCA, isDirectory: true)
        let floatingDir = wallpaperDir.appendingPathComponent(floatingCA, isDirectory: true)
        let assetsDir = backgroundDir.appendingPathComponent("assets", isDirectory: true)

        for dir in [descrURL, contentsDir, wallpaperDir, backgroundDir, floatingDir, assetsDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Extract frames ----------------------------------------------------
        let frameCount = try extractFrames(asset: asset,
                                           track: track,
                                           transform: preferredTransform,
                                           into: assetsDir,
                                           progress: progress)
        let effectiveFrames = max(frameCount, 1)
        let effectiveDur = Double(effectiveFrames) / Double(max(fps, 1))
        _ = animDur

        // main.caml (background animation) ---------------------------------
        let caml = makeBackgroundCAML(width: width,
                                      height: height,
                                      duration: effectiveDur,
                                      frameCount: effectiveFrames,
                                      autoReverses: autoReverses)
        try writeString(caml, to: backgroundDir.appendingPathComponent("main.caml"))
        try writeString(makeIndexXML(width: width, height: height),
                        to: backgroundDir.appendingPathComponent("index.xml"))

        // Floating CAML (static backdrop) ------------------------------------
        try writeString(makeFloatingCAML(width: width, height: height),
                        to: floatingDir.appendingPathComponent("main.caml"))

        // Provider metadata --------------------------------------------------
        try writeString("9183",
                        to: descrURL.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier"))
        try writeString("PRPosterRoleLockScreen",
                        to: descrURL.appendingPathComponent("com.apple.posterkit.role.identifier"))

        try makeProviderInfoPlist()
            .write(to: descrURL.appendingPathComponent("providerInfo.plist"))

        try writeString(makeUserInfoPlist(wallpaperFileName: wallpaperName),
                        to: contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.userInfo"))

        try writeString(makeWallpaperPlist(wallpaperName: wallpaperName,
                                           backgroundCA: backgroundCA,
                                           floatingCA: floatingCA),
                        to: wallpaperDir.appendingPathComponent("Wallpaper.plist"))

        return descrURL
    }

    private static func writeString(_ string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw DescriptorError.writeFailed(url.lastPathComponent)
        }
        try data.write(to: url)
    }

    // MARK: - Frame extraction
    private static func extractFrames(asset: AVURLAsset,
                                      track: AVAssetTrack,
                                      transform: CGAffineTransform,
                                      into assetsDir: URL,
                                      progress: ((Int, Int) -> Void)?) throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(readerOutput)
        reader.startReading()

        let context = CIContext()
        var frameCount = 0
        let estimate = max(1, Int(track.nominalFrameRate * Float(CMTimeGetSeconds(asset.duration))))

        while let sampleBuffer = readerOutput.copyNextSampleBuffer(),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            try autoreleasepool {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer).transformed(by: transform)
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
                   let jpg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7) {
                    try jpg.write(to: assetsDir.appendingPathComponent("\(frameCount).jpg"))
                    frameCount += 1
                    progress?(frameCount, estimate)
                }
            }
        }

        if reader.status == .failed {
            throw DescriptorError.frameReadFailed
        }
        return frameCount
    }

    // MARK: - CAML templates
    private static func makeBackgroundCAML(width: Int, height: Int,
                                           duration: Double, frameCount: Int,
                                           autoReverses: Bool) -> String {
        var values = ""
        for i in 0..<frameCount {
            values += "\t\t\t<CGImage src=\"assets/\(i).jpg\"/>\n"
        }
        return """
<?xml version="1.0" encoding="UTF-8"?>

<caml xmlns="http://www.apple.com/CoreAnimation/1.0">
<CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" hidden="0" name="_FLOATING" position="\(width/2) \(height/2)">
<sublayers>
<CATransformLayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" allowsHitTesting="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" name="Chip" position="\(width/2) \(height/2)">
<sublayers>
<CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" name="CALayer1" position="\(width/2) \(height/2)">
<contents type="CGImage" src="assets/0.jpg"/>
<animations>
<animation type="CAKeyframeAnimation" calculationMode="linear" keyPath="contents" beginTime="1e-100" duration="\(duration)" removedOnCompletion="0" repeatCount="inf" repeatDuration="0" speed="1" timeOffset="0" autoreverses="\(autoReverses ? 1 : 0)">
<values>
\(values)</values>
</animation>
      </animations>
    </CALayer>
  </sublayers>
    </CATransformLayer>
  </sublayers>
  <states>
    <LKState name="Locked">
  <elements/>
    </LKState>
    <LKState name="Unlock">
  <elements/>
    </LKState>
    <LKState name="Sleep">
  <elements/>
    </LKState>
  </states>
  <stateTransitions>
    <LKStateTransition fromState="*" toState="Unlock">
  <elements/>
    </LKStateTransition>
    <LKStateTransition fromState="Unlock" toState="*">
  <elements/>
    </LKStateTransition>
    <LKStateTransition fromState="*" toState="Locked">
  <elements/>
    </LKStateTransition>
    <LKStateTransition fromState="Locked" toState="*">
  <elements/>
    </LKStateTransition>
    <LKStateTransition fromState="*" toState="Sleep">
  <elements/>
    </LKStateTransition>
    <LKStateTransition fromState="Sleep" toState="*">
  <elements/>
    </LKStateTransition>
  </stateTransitions>
</CALayer>
</caml>
"""
    }

    private static func makeFloatingCAML(width: Int, height: Int) -> String {
        let half = width / 2
        return """
<?xml version="1.0" encoding="UTF-8"?>

<caml xmlns="http://www.apple.com/CoreAnimation/1.0">
  <CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" bounds="0 0 \(width) \(width)" contentsFormat="RGBA8" cornerCurve="circular" hidden="0" name="_BACKGROUND" position="\(half) \(half)">
    <sublayers>
      <CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" anchorPoint="0 0" bounds="0 0 0 0" contentsFormat="RGBA8" cornerCurve="circular" name="_CENTER_BACKGROUND" position="\(half) \(half)"/>
    </sublayers>
    <states>
      <LKState name="Locked"><elements/></LKState>
      <LKState name="Unlock"><elements/></LKState>
      <LKState name="Sleep"><elements/></LKState>
    </states>
    <stateTransitions>
      <LKStateTransition fromState="*" toState="Unlock"><elements/></LKStateTransition>
      <LKStateTransition fromState="Unlock" toState="*"><elements/></LKStateTransition>
      <LKStateTransition fromState="*" toState="Locked"><elements/></LKStateTransition>
      <LKStateTransition fromState="Locked" toState="*"><elements/></LKStateTransition>
      <LKStateTransition fromState="*" toState="Sleep"><elements/></LKStateTransition>
      <LKStateTransition fromState="Sleep" toState="*"><elements/></LKStateTransition>
    </stateTransitions>
  </CALayer>
</caml>
"""
    }

    private static func makeIndexXML(width: Int, height: Int) -> String {
        return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>assetManifest</key>
    <string>assetManifest.caml</string>
    <key>documentHeight</key>
    <real>\(height)</real>
    <key>documentResizesToView</key>
    <true/>
    <key>documentWidth</key>
    <real>\(width)</real>
    <key>dynamicGuidesEnabled</key>
    <true/>
    <key>geometryFlipped</key>
    <false/>
    <key>guidesEnabled</key>
    <true/>
    <key>interactiveMouseEventsEnabled</key>
    <true/>
    <key>interactiveShowsCursor</key>
    <true/>
    <key>interactiveTouchEventsEnabled</key>
    <false/>
    <key>loopEnd</key>
    <real>0.0</real>
    <key>loopStart</key>
    <real>0.0</real>
    <key>loopingEnabled</key>
    <false/>
    <key>multitouchDisablesMouse</key>
    <false/>
    <key>multitouchEnabled</key>
    <false/>
    <key>presentationMouseEventsEnabled</key>
    <true/>
    <key>presentationShowsCursor</key>
    <true/>
    <key>presentationTouchEventsEnabled</key>
    <false/>
    <key>rootDocument</key>
    <string>main.caml</string>
    <key>savesWindowFrame</key>
    <false/>
    <key>scalesToFitInPlayer</key>
    <true/>
    <key>showsTouches</key>
    <true/>
    <key>snappingEnabled</key>
    <true/>
    <key>timelineMarkers</key>
    <string>[(null)]</string>
    <key>touchesColor</key>
    <string>1 1 0 0.8</string>
    <key>unitsInPixelsInPlayer</key>
    <true/>
</dict>
</plist>
"""
    }

    private static func makeProviderInfoPlist() -> Data {
        // Minimal NSKeyedArchiver-encoded dict with a last-use date.
        let dict: [String: Any] = ["kConfigurationLastUseDateKey": Date()]
        return (try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)) ?? Data()
    }

    private static func makeUserInfoPlist(wallpaperFileName: String) -> String {
        return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>posterEnvironmentOverrides</key>
\t<data>
\te30=
\t</data>
\t<key>wallpaperRepresentingFileName</key>
\t<string>\(wallpaperFileName)</string>
\t<key>wallpaperRepresentingIdentifier</key>
\t<string>9999</string>
</dict>
</plist>
"""
    }

    private static func makeWallpaperPlist(wallpaperName: String,
                                           backgroundCA: String,
                                           floatingCA: String) -> String {
        return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>appearanceAware</key>
\t<true/>
\t<key>assets</key>
\t<dict>
\t\t<key>lockAndHome</key>
\t\t<dict>
\t\t\t<key>default</key>
\t\t\t<dict>
\t\t\t\t<key>backgroundAnimationFileName</key>
\t\t\t\t<string>\(backgroundCA)</string>
\t\t\t\t<key>floatingAnimationFileNameKey</key>
\t\t\t\t<string>\(floatingCA)</string>
\t\t\t\t<key>identifier</key>
\t\t\t\t<integer>9183</integer>
\t\t\t\t<key>name</key>
\t\t\t\t<string>Chip</string>
\t\t\t\t<key>type</key>
\t\t\t\t<string>LayeredAnimation</string>
\t\t\t</dict>
\t\t</dict>
\t</dict>
\t<key>contentVersion</key>
\t<real>2.01</real>
\t<key>family</key>
\t<string>Chip</string>
\t<key>identifier</key>
\t<integer>9183</integer>
\t<key>logicalScreenClass</key>
\t<string>\(screenClass)</string>
\t<key>name</key>
\t<string>Chip</string>
\t<key>preferredProminentColor</key>
\t<dict>
\t\t<key>dark</key>
\t\t<string>#00000</string>
\t\t<key>default</key>
\t\t<string>#FFFFFF</string>
\t</dict>
\t<key>version</key>
\t<integer>1</integer>
</dict>
</plist>
"""
    }
}
