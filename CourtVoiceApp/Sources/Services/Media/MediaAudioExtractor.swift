import AVFoundation
import Foundation

@MainActor
struct MediaAudioExtractor {
  func prepareLocalCopy(of sourceURL: URL) throws -> URL {
    let scoped = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if scoped { sourceURL.stopAccessingSecurityScopedResource() }
    }

    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("courtvoice-import-\(UUID().uuidString)")
      .appendingPathExtension(sourceURL.pathExtension)
    try FileManager.default.copyItem(at: sourceURL, to: destination)
    return destination
  }

  func extractM4A(from sourceURL: URL) async throws -> URL {
    let asset = AVURLAsset(url: sourceURL)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    guard audioTracks.isEmpty == false else {
      throw MediaAnalysisError.noAudioTrack
    }

    guard
      let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetAppleM4A
      )
    else {
      throw MediaAnalysisError.cannotCreateExporter
    }
    guard exportSession.supportedFileTypes.contains(.m4a) else {
      throw MediaAnalysisError.unsupportedExportType
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("courtvoice-audio-\(UUID().uuidString).m4a")
    try? FileManager.default.removeItem(at: outputURL)

    #if compiler(>=6.2)
      try await exportSession.export(to: outputURL, as: .m4a)
    #else
      try await withCheckedThrowingContinuation { continuation in
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.exportAsynchronously {
          switch exportSession.status {
          case .completed:
            continuation.resume()
          case .cancelled:
            continuation.resume(throwing: CancellationError())
          default:
            continuation.resume(
              throwing: exportSession.error ?? MediaAnalysisError.cannotCreateExporter)
          }
        }
      }
    #endif

    return outputURL
  }
}
