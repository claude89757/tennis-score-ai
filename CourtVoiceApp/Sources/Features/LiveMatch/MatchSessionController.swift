import CourtVoiceAI
import CourtVoiceCore
import Foundation
import Observation

@MainActor
@Observable
final class MatchSessionController: Identifiable {
  let id: UUID

  private(set) var timeline: MatchTimeline
  private let repository: MatchRepository
  private let speechConfiguration: SpeechConfiguration
  private let credentialStore: ProviderCredentialStore
  private let parser = TranscriptIntentParser()
  private let structuredParser = StructuredScoreIntentParser()
  private let resolver = ScoreIntentResolver()
  private var speechProvider: (any LiveSpeechProvider)?
  private let reasoningTask = CancellableTaskHandle()
  private let utteranceCommitTask = CancellableTaskHandle()
  private let reasoningClientOverride: (any ScoreReasoningClient)?

  var lastErrorMessage: String?
  var lastActionDescription = "Match ready"
  var speechState: SpeechSessionState = .idle
  var lastTranscript = ""
  var lastTranscriptIsFinal = false
  var transcriptLines: [LiveTranscriptLine] = []
  var reasoningPhase: ScoreReasoningPhase = .idle
  var reasoningThinking = ""
  var reasoningAnswer = ""
  var activeProviderID: String?
  private var lastCommittedSpeechID: UUID?
  private var lastHandledUtteranceKey: String?
  private var lastHandledUtteranceAt: Date?

  var state: MatchState { timeline.currentState }
  var isListening: Bool { speechState.isActive }

  init(
    initialState: MatchState,
    repository: MatchRepository,
    speechConfiguration: SpeechConfiguration = .standard,
    credentialStore: ProviderCredentialStore = ProviderCredentialStore(),
    reasoningClient: (any ScoreReasoningClient)? = nil
  ) throws {
    id = initialState.id
    self.repository = repository
    self.speechConfiguration = speechConfiguration
    self.credentialStore = credentialStore
    reasoningClientOverride = reasoningClient

    var newTimeline = MatchTimeline(initialState: initialState)
    try newTimeline.append(
      MatchEvent(
        kind: .matchStarted,
        evidence: ScoreEvidence(source: .manual),
        idempotencyKey: "match-start-\(initialState.id.uuidString)"
      )
    )
    timeline = newTimeline
  }

  init(
    savedMatch: SavedMatch,
    repository: MatchRepository,
    speechConfiguration: SpeechConfiguration = .standard,
    credentialStore: ProviderCredentialStore = ProviderCredentialStore(),
    reasoningClient: (any ScoreReasoningClient)? = nil
  ) {
    id = savedMatch.id
    timeline = savedMatch.timeline
    self.repository = repository
    self.speechConfiguration = speechConfiguration
    self.credentialStore = credentialStore
    reasoningClientOverride = reasoningClient
    lastActionDescription = "Match restored"
  }

  func startListening() async {
    guard speechProvider == nil, state.status == .inProgress else { return }

    let factory = SpeechProviderFactory(
      configuration: speechConfiguration,
      credentialStore: credentialStore
    )
    let candidates = await factory.providerCandidates()
    var failures: [String] = []

    for kind in candidates {
      do {
        let provider = try await factory.makeProvider(kind)
        try await provider.start(
          locale: speechConfiguration.locale,
          contextualPhrases: TennisSpeechVocabulary.contextualPhrases,
          onTranscription: { [weak self] transcription in
            Task { @MainActor [weak self] in
              await self?.handleTranscription(transcription)
            }
          },
          onStateChange: { [weak self] state in
            self?.speechState = state
          }
        )
        speechProvider = provider
        activeProviderID = provider.providerID
        return
      } catch {
        failures.append("\(kind.title): \(error.localizedDescription)")
      }
    }

    let message =
      failures.isEmpty
      ? "No speech provider is available."
      : failures.joined(separator: "\n")
    speechState = .failed(message)
    lastErrorMessage = message
  }

  func stopListening() async {
    let provider = speechProvider
    speechProvider = nil
    reasoningTask.cancel()
    utteranceCommitTask.cancel()
    await provider?.stop()
    speechState = .idle
    activeProviderID = nil
  }

  func ingestFinalTranscriptForTesting(
    _ text: String,
    confidence: Double = 0.99,
    providerID: String = "test.local"
  ) async {
    await ingestTranscriptForTesting(text, confidence: confidence, isFinal: true, providerID: providerID)
  }

  func ingestTranscriptForTesting(
    _ text: String,
    confidence: Double = 0.99,
    isFinal: Bool = true,
    providerID: String = "test.local"
  ) async {
    await handleTranscription(
      SpeechTranscription(
        text: text,
        confidence: confidence,
        isFinal: isFinal,
        providerID: providerID
      )
    )
  }

  func waitForReasoningToSettleForTesting() async {
    for _ in 0..<200 {
      switch reasoningPhase {
      case .thinking, .answering:
        try? await Task.sleep(for: .milliseconds(10))
      case .idle, .complete, .failed:
        return
      }
    }
  }

  func persist() async throws {
    try await repository.save(timeline)
  }

  private func handleTranscription(_ transcription: SpeechTranscription) async {
    lastTranscript = transcription.text
    lastTranscriptIsFinal = transcription.isFinal
    appendTranscript(transcription)

    if transcription.isFinal {
      utteranceCommitTask.cancel()
      await commitUtteranceIfNeeded(transcription)
      return
    }

    scheduleStableUtteranceCommit(transcription)
  }

  private func scheduleStableUtteranceCommit(_ transcription: SpeechTranscription) {
    let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count >= 2 else { return }

    utteranceCommitTask.store(
      Task { [weak self] in
        guard let self else { return }
        try? await Task.sleep(for: .seconds(self.speechConfiguration.utteranceCommitDelay))
        guard Task.isCancelled == false else { return }
        let current = self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard current == text else { return }
        self.markLatestTranscriptFinal()
        await self.commitUtteranceIfNeeded(
          SpeechTranscription(
            id: transcription.id,
            text: current,
            confidence: nil,
            isFinal: true,
            providerID: transcription.providerID
          )
        )
      }
    )
  }

  private func commitUtteranceIfNeeded(_ transcription: SpeechTranscription) async {
    let key = utteranceKey(transcription.text)
    guard key.isEmpty == false else { return }
    if key == lastHandledUtteranceKey,
      let handledAt = lastHandledUtteranceAt,
      Date().timeIntervalSince(handledAt) < 2.5
    {
      return
    }
    lastHandledUtteranceKey = key
    lastHandledUtteranceAt = Date()

    let candidate = parser.parse(transcription.text)
    await applyResolvedCandidate(candidate, transcription: transcription)
    await startScoreReasoning(for: transcription)
  }

  private func scoringConfidence(
    for candidate: IntentCandidate,
    transcription: SpeechTranscription
  ) -> Double {
    if candidate.parserID.hasPrefix("deepseek") {
      return candidate.confidence
    }
    guard let audioConfidence = transcription.confidence else {
      return candidate.confidence
    }
    return min(candidate.confidence, audioConfidence)
  }

  private func markLatestTranscriptFinal() {
    lastTranscriptIsFinal = true
    guard transcriptLines.isEmpty == false else { return }
    transcriptLines[transcriptLines.count - 1].isFinal = true
  }

  private func utteranceKey(_ text: String) -> String {
    text
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .lowercased()
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  @discardableResult
  private func applyResolvedCandidate(
    _ candidate: IntentCandidate,
    transcription: SpeechTranscription
  ) async -> Bool {
    let combinedConfidence = scoringConfidence(for: candidate, transcription: transcription)
    let isTrusted =
      candidate.requiresConfirmation == false
      && combinedConfidence >= speechConfiguration.autoAcceptConfidence

    if isTrusted == false {
      lastActionDescription = "Held: the agent needs a clearer call before changing the score."
      return false
    }

    if candidate.intent == .undo {
      await performUndo(evidence: evidence(for: transcription))
      lastCommittedSpeechID = transcription.id
      return true
    }

    switch resolver.resolve(candidate, state: state) {
    case .event(let kind):
      await applySpeechEvent(kind, transcription: transcription)
      lastCommittedSpeechID = transcription.id
      return true
    case .events(let kinds):
      for (offset, kind) in kinds.enumerated() {
        await apply(
          kind,
          evidence: evidence(for: transcription),
          idempotencyKey:
            "speech-\(transcription.providerID)-\(transcription.id.uuidString)-\(offset)",
          successDescription: "Agent scored: \(transcription.text)"
        )
      }
      lastCommittedSpeechID = transcription.id
      return true
    case .alreadyCurrent:
      lastActionDescription = "Heard the current score; no change"
      return true
    case .confirmationRequired(let reason):
      lastActionDescription = "Held: \(reason)"
      return false
    case .ignored(let reason):
      lastActionDescription = reason
      return candidate.intent != .unknown
    }
  }

  private func appendTranscript(_ transcription: SpeechTranscription) {
    if var last = transcriptLines.last, last.isFinal == false {
      last.text = transcription.text
      last.isFinal = transcription.isFinal
      transcriptLines[transcriptLines.count - 1] = last
    } else {
      transcriptLines.append(
        LiveTranscriptLine(
          id: transcription.id,
          text: transcription.text,
          isFinal: transcription.isFinal
        )
      )
    }
    if transcriptLines.count > 8 {
      transcriptLines.removeFirst(transcriptLines.count - 8)
    }
  }

  private func startScoreReasoning(for transcription: SpeechTranscription) async {
    guard speechConfiguration.scoreReasoningEnabled else { return }

    let client: (any ScoreReasoningClient)?
    if let reasoningClientOverride {
      client = reasoningClientOverride
    } else if let key = try? await credentialStore.value(for: .deepseekAPIKey),
      let endpoint = URL(string: speechConfiguration.scoreReasoningEndpoint)
    {
      client = DeepSeekScoreReasoningClient(
        apiKey: key,
        endpoint: endpoint,
        model: speechConfiguration.scoreReasoningModel,
        reasoningEffort: speechConfiguration.scoreReasoningEffort
      )
    } else {
      reasoningPhase = .idle
      return
    }

    guard let client else { return }

    reasoningThinking = ""
    reasoningAnswer = ""
    reasoningPhase = .thinking

    reasoningTask.store(
      Task { [weak self] in
        guard let self else { return }
        do {
          let answer = try await client.streamProposal(
            transcript: transcription.text,
            matchContext: self.matchContextDescription()
          ) { event in
            Task { @MainActor [weak self] in
              self?.consumeReasoningEvent(event)
            }
          }
          guard Task.isCancelled == false else { return }
          await self.finishReasoning(answer: answer, transcription: transcription)
        } catch is CancellationError {
          return
        } catch {
          guard Task.isCancelled == false else { return }
          self.reasoningPhase = .failed(error.localizedDescription)
        }
      }
    )
  }

  private func consumeReasoningEvent(_ event: ScoreReasoningEvent) {
    switch event {
    case .thinkingDelta(let delta):
      reasoningPhase = .thinking
      reasoningThinking += delta
    case .answerDelta(let delta):
      reasoningPhase = .answering
      reasoningAnswer += delta
    }
  }

  private func finishReasoning(answer: String, transcription: SpeechTranscription) async {
    if reasoningAnswer.isEmpty {
      reasoningAnswer = answer
    }
    guard lastCommittedSpeechID != transcription.id,
      let candidate = structuredParser.parse(jsonText: answer)
    else {
      reasoningPhase = .complete
      return
    }
    await applyResolvedCandidate(candidate, transcription: transcription)
    reasoningPhase = .complete
  }

  private func matchContextDescription() -> String {
    """
    home=\(state.teams.home.displayName)
    away=\(state.teams.away.displayName)
    server=\(state.server.rawValue)
    spoken_score=\(ScoreFormatter.spokenScore(for: state, locale: speechConfiguration.locale))
    status=\(String(describing: state.status))
    """
  }

  private func applySpeechEvent(
    _ kind: MatchEventKind,
    transcription: SpeechTranscription
  ) async {
    await apply(
      kind,
      evidence: evidence(for: transcription),
      idempotencyKey: "speech-\(transcription.providerID)-\(transcription.id.uuidString)",
      successDescription: "Agent scored: \(transcription.text)"
    )
  }

  private func evidence(for transcription: SpeechTranscription) -> ScoreEvidence {
    ScoreEvidence(
      transcript: transcription.text,
      confidence: transcription.confidence,
      providerID: transcription.providerID,
      source: transcription.providerID == "apple.on-device" ? .speechLocal : .speechCloud
    )
  }

  private func performUndo(evidence: ScoreEvidence) async {
    do {
      _ = try timeline.revokeLastMutableEvent(evidence: evidence)
      lastActionDescription = "Last scoring action undone"
      try await persist()
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  private func apply(
    _ kind: MatchEventKind,
    evidence: ScoreEvidence,
    idempotencyKey: String? = nil,
    successDescription: String
  ) async {
    do {
      try timeline.append(
        MatchEvent(
          kind: kind,
          evidence: evidence,
          idempotencyKey: idempotencyKey
        )
      )
      lastActionDescription = successDescription
      try await persist()
      if state.isComplete {
        await stopListening()
      }
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }
}
