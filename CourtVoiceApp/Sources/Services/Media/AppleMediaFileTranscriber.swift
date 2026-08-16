import Foundation
import Speech

@MainActor
final class AppleMediaFileTranscriber: MediaFileTranscriber {
  let providerID = "apple.file.on-device"
  let displayName = "Apple on-device"

  private var recognitionTask: SFSpeechRecognitionTask?

  func transcribe(audioURL: URL, locale: Locale) async throws -> [MediaUtterance] {
    guard await SpeechPermissionCenter.requestSpeechRecognition() == .authorized else {
      throw SpeechProviderError.speechRecognitionDenied
    }
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      throw MediaAnalysisError.providerUnavailable(
        "Apple Speech is unavailable for \(locale.identifier)."
      )
    }
    guard recognizer.supportsOnDeviceRecognition else {
      throw MediaAnalysisError.providerUnavailable(
        "On-device file recognition is not installed for \(locale.identifier)."
      )
    }

    let request = SFSpeechURLRecognitionRequest(url: audioURL)
    request.shouldReportPartialResults = false
    request.requiresOnDeviceRecognition = true
    request.contextualStrings = TennisSpeechVocabulary.contextualPhrases
    request.taskHint = .dictation

    return try await withCheckedThrowingContinuation { continuation in
      var finished = false
      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
        Task { @MainActor in
          guard finished == false else { return }
          if let result, result.isFinal {
            finished = true
            self?.recognitionTask = nil
            let utterances = Self.group(result.bestTranscription.segments)
            if utterances.isEmpty {
              continuation.resume(throwing: MediaAnalysisError.emptyTranscription)
            } else {
              continuation.resume(returning: utterances)
            }
          } else if let error {
            finished = true
            self?.recognitionTask = nil
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }

  private static func group(_ segments: [SFTranscriptionSegment]) -> [MediaUtterance] {
    guard let first = segments.first else { return [] }

    var rows: [MediaUtterance] = []
    var words = [first.substring]
    var start = first.timestamp
    var end = first.timestamp + first.duration
    var confidence = Double(first.confidence)
    var confidenceCount = 1

    func appendCurrent() {
      let text = words.joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard text.isEmpty == false else { return }
      rows.append(
        MediaUtterance(
          startTime: start,
          endTime: end,
          text: text,
          confidence: confidence / Double(confidenceCount),
          providerID: "apple.file.on-device"
        )
      )
    }

    for segment in segments.dropFirst() {
      let gap = segment.timestamp - end
      if gap > 0.85 {
        appendCurrent()
        words = [segment.substring]
        start = segment.timestamp
        confidence = Double(segment.confidence)
        confidenceCount = 1
      } else {
        words.append(segment.substring)
        confidence += Double(segment.confidence)
        confidenceCount += 1
      }
      end = segment.timestamp + segment.duration
    }
    appendCurrent()
    return rows
  }
}
