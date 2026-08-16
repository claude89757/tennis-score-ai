import Foundation
import Observation

@MainActor
@Observable
final class MediaAnalysisViewModel {
  enum Phase: Equatable {
    case idle
    case copying
    case extractingAudio
    case transcribing(provider: String)
    case resolving
    case complete
    case failed(String)

    var title: String {
      switch self {
      case .idle: "Ready"
      case .copying: "Preparing selected media"
      case .extractingAudio: "Extracting audio"
      case .transcribing(let provider): "Transcribing with \(provider)"
      case .resolving: "Validating tennis score events"
      case .complete: "Analysis complete"
      case .failed: "Analysis failed"
      }
    }
  }

  private(set) var phase: Phase = .idle
  private(set) var progress = 0.0
  private(set) var sourceFilename: String?
  private(set) var analysis: MediaScoreAnalysis?
  var errorMessage: String?

  private var analysisTask: Task<Void, Never>?

  deinit {
    analysisTask?.cancel()
  }

  func analyze(
    sourceURL: URL,
    draft: MatchConfigurationDraft,
    configuration: SpeechConfiguration,
    credentialStore: ProviderCredentialStore
  ) {
    analysisTask?.cancel()
    analysisTask = Task { [weak self] in
      guard let self else { return }
      await self.performAnalysis(
        sourceURL: sourceURL,
        draft: draft,
        configuration: configuration,
        credentialStore: credentialStore
      )
    }
  }

  func cancel() {
    analysisTask?.cancel()
    analysisTask = nil
    phase = .idle
    progress = 0
  }

  func save(to repository: MatchRepository) async throws {
    guard let analysis else { return }
    try await repository.save(analysis.timeline)
  }

  private func performAnalysis(
    sourceURL: URL,
    draft: MatchConfigurationDraft,
    configuration: SpeechConfiguration,
    credentialStore: ProviderCredentialStore
  ) async {
    do {
      analysis = nil
      errorMessage = nil
      sourceFilename = sourceURL.lastPathComponent

      phase = .copying
      progress = 0.08
      let extractor = MediaAudioExtractor()
      let localURL = try extractor.prepareLocalCopy(of: sourceURL)
      defer { try? FileManager.default.removeItem(at: localURL) }

      try Task.checkCancellation()
      phase = .extractingAudio
      progress = 0.20
      let audioURL = try await extractor.extractM4A(from: localURL)
      defer { try? FileManager.default.removeItem(at: audioURL) }

      try Task.checkCancellation()
      let factory = MediaFileTranscriberFactory(
        configuration: configuration,
        credentialStore: credentialStore
      )
      let transcriber = try await factory.makeTranscriber()
      phase = .transcribing(provider: transcriber.displayName)
      progress = 0.36
      let utterances = try await transcriber.transcribe(
        audioURL: audioURL,
        locale: configuration.locale
      )

      try Task.checkCancellation()
      phase = .resolving
      progress = 0.78
      analysis = MediaScoreTimelineBuilder().build(
        initialState: draft.makeInitialState(),
        utterances: utterances,
        automaticAcceptanceThreshold: configuration.autoAcceptConfidence
      )
      progress = 1
      phase = .complete
    } catch is CancellationError {
      phase = .idle
      progress = 0
    } catch {
      errorMessage = error.localizedDescription
      phase = .failed(error.localizedDescription)
    }
  }
}
