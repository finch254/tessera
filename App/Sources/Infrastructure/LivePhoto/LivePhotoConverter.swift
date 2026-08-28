import AVFoundation
import CoreImage
import Photos
import UIKit

// MARK: - Errors
enum LivePhotoError: Error, LocalizedError {
    case noVideoTrack
    case frameExtractionFailed
    case writerFailed(String)
    case photoLibraryDenied

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The video has no video track."
        case .frameExtractionFailed: return "Could not extract a key frame from the video."
        case .writerFailed(let msg): return "Video processing failed: \(msg)"
        case .photoLibraryDenied: return "Photo library access is required to save Live Photos."
        }
    }
}

// MARK: - Live Photo converter
/// Converts a short video clip into an iOS Live Photo and saves it to the
/// photo library. Based on the standard paired-resource technique: a JPEG key
/// frame carrying the content identifier in the Apple MakerNote, plus a .mov
/// carrying the same identifier in a QuickTime metadata track.
final class LivePhotoConverter {
    static let shared = LivePhotoConverter()

    /// Live Photos are short; cap the clip so conversion stays fast.
    static let maxDuration: Double = 3.0

    private var tempDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LivePhotoWork", isDirectory: true)
    }

    /// Convert the video at `videoURL` into a Live Photo and save it.
    func convertToLivePhoto(videoURL: URL) async throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw LivePhotoError.noVideoTrack
        }

        let assetIdentifier = UUID().uuidString

        // 1. Key frame image (the still the Live Photo rests on).
        let keyImage = try await extractKeyFrame(from: asset)

        // 2. Paired video carrying the content identifier.
        let pairedVideoURL = try await writePairedVideo(from: asset, track: track, identifier: assetIdentifier)

        // 3. JPEG key photo carrying the same identifier in the MakerNote.
        let photoURL = try writeKeyPhoto(keyImage, identifier: assetIdentifier)

        // 4. Combine and save as a Live Photo.
        try await saveLivePhoto(photoURL: photoURL, videoURL: pairedVideoURL)

        // Clean up temp files.
        try? FileManager.default.removeItem(at: pairedVideoURL)
        try? FileManager.default.removeItem(at: photoURL)
    }

    // MARK: - Key frame
    private func extractKeyFrame(from asset: AVURLAsset) async throws -> UIImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1920, height: 1920)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            // Fall back to frame 0.
            let (cgImage, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        }
    }

    // MARK: - Paired video
    private func writePairedVideo(from asset: AVURLAsset, track: AVAssetTrack, identifier: String) async throws -> URL {
        let outputURL = tempDir.appendingPathComponent("\(identifier).mov")
        try? FileManager.default.removeItem(at: outputURL)

        let duration = try await asset.load(.duration)
        let trimSeconds = min(CMTimeGetSeconds(duration), Self.maxDuration)
        let timeRange = CMTimeRange(start: .zero,
                                    duration: CMTime(seconds: trimSeconds, preferredTimescale: 600))

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height
        ])
        writerInput.transform = transform
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Metadata input that carries the content identifier.
        let spec: NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
                "mdta/com.apple.quicktime.content.identifier",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
                "com.apple.metadata.datatype.UTF-8"
        ]
        var formatDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [spec] as CFArray,
            formatDescriptionOut: &formatDesc
        )
        let metadataInput = AVAssetWriterInput(mediaType: .metadata,
                                               outputSettings: nil,
                                               sourceFormatHint: formatDesc)
        writer.add(metadataInput)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        // Append the content identifier metadata group at the start.
        let item = AVMutableMetadataItem()
        item.key = "com.apple.quicktime.content.identifier" as NSCopying & NSObjectProtocol
        item.keySpace = .quickTimeMetadata
        item.value = identifier as NSCopying & NSObjectProtocol
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        let group = AVTimedMetadataGroup(items: [item],
                                         timeRange: CMTimeRange(start: .zero,
                                                                duration: CMTime(seconds: 0.1, preferredTimescale: 600)))
        metadataAdaptor.append(group)
        metadataInput.markAsFinished()

        // Pump video frames through the writer.
        var finished = false
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "tessera.livephoto.write")) {
                guard !finished else { return }
                while writerInput.isReadyForMoreMediaData {
                    if let sample = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sample)
                    } else {
                        finished = true
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                cont.resume()
                            } else {
                                cont.resume(throwing: writer.error ?? LivePhotoError.writerFailed(writer.status.rawValue.description))
                            }
                        }
                        break
                    }
                }
            }
        }

        return outputURL
    }

    // MARK: - Key photo
    private func writeKeyPhoto(_ image: UIImage, identifier: String) throws -> URL {
        let url = tempDir.appendingPathComponent("\(identifier).jpg")
        try? FileManager.default.removeItem(at: url)

        guard let data = image.jpegData(compressionQuality: 0.95),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LivePhotoError.frameExtractionFailed
        }

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw LivePhotoError.frameExtractionFailed
        }
        // The content identifier lives in Apple MakerNote tag 17.
        let makerNote: [String: Any] = [
            kCGImagePropertyMakerAppleDictionary as String: ["17": identifier]
        ]
        CGImageDestinationAddImage(dest, cgImage, makerNote as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw LivePhotoError.frameExtractionFailed
        }
        return url
    }

    // MARK: - Save
    private func saveLivePhoto(photoURL: URL, videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw LivePhotoError.photoLibraryDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: photoURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
        }
    }
}
