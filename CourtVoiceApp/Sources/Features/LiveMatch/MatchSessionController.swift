import CourtVoiceAI
import CourtVoiceCore
import Foundation
import Observation

struct PendingSpeechAction: Identifiable, Equatable {
  enum Proposal: Equatable {
    case event(MatchEventKind)
    case undo
    case correction
  }

  let id = UUID()
  let proposal: Proposal
  let transcription: SpeechTranscription
  let confidence: Double
  let explanation: String
}

@MainActor
@Observable
final class MatchSessionController: Identifiable {
  let id: UUID

  private(set) var timeline: MatchTimeline
  private let repository: MatchRepository
  private let speechConfiguration: SpeechConfiguration
  private let credentialStore: ProviderCredentialStore
  private let parser = TranscriptIntentParser()
  private let resolver = ScoreIntentResolver()
  private var speechProvider: (any LiveSpeechProvider)?

  var lastErrorMessage: String?
  var lastActionDescription = "Match ready"
  var isShowingCorrection = false
  var speechState: SpeechSessionState = .idle
  var lastTranscript = ""
  var lastTranscriptIsFinal = false
  var activeProviderID: String?
  var pendingSpeechAction: PendingSpeechAction?

  var state: MatchState { timeline.currentState }
  var isListening: Bool { speechState.isActive }

  init(
    initialState: MatchState,
    repository: MatchRepository,
    speechConfiguration: SpeechConfiguration = .standard,
    credentialStore: ProviderCredentialStore = ProviderCredentialStore()
  ) throws {
    id = initialState.id
    self.repository = repository
    self.speechConfiguration = speechConfiguration
    self.credentialStore = credentialStore

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
    credentialStore: ProviderCredentialStore = ProviderCredentialStore()
  ) {
    id = savedMatch.id
    timeline = savedMatch.timeline
    self.repository = repository
    self.speechConfiguration = speechConfiguration
    self.credentialStore = credentialStore
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
    await provider?.stop()
    speechState = .idle
    activeProviderID = nil
  }

  func awardPoint(
    to side: TeamSide,
    source: MatchSource = .manual,
    transcript: String? = nil,
    confidence: Double? = nil,
    providerID: String? = nil,
    idempotencyKey: String? = nil
  ) async {
    await apply(
      .pointAwarded(side),
      evidence: ScoreEvidence(
        transcript: transcript,
        confidence: confidence,
        providerID: providerID,
        source: source
      ),
      idempotencyKey: idempotencyKey,
      successDescription: "Point to \(state.teams[side].displayName)"
    )
  }

  func undo() async {
    await performUndo(evidence: ScoreEvidence(source: .manual))
  }

  func togglePause() async {
    let kind: MatchEventKind
    let description: String

    switch state.status {
    case .inProgress:
      kind = .matchPaused
      description = "Match paused"
    case .paused:
      kind = .matchResumed
      description = "Match resumed"
    default:
      return
    }

    await apply(
      kind,
      evidence: ScoreEvidence(source: .manual),
      successDescription: description
    )

    if kind == .matchPaused {
      await stopListening()
    }
  }

  func changeServer(to side: TeamSide) async {
    await apply(
      .serverChanged(side),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Server changed to \(state.teams[side].displayName)"
    )
  }

  func applyCorrection(_ correction: ScoreCorrection) async {
    pendingSpeechAction = nil
    await apply(
      .scoreCorrected(correction),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Score corrected"
    )
  }

  func endMatch(winner: TeamSide) async {
    await apply(
      .matchEnded(winner: winner),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Match ended"
    )
    await stopListening()
  }

  func confirmPendingSpeechAction() async {
    guard let pendingSpeechAction else { return }
    self.pendingSpeechAction = nil

    switch pendingSpeechAction.proposal {
    case .event(let kind):
      await applySpeechEvent(kind, transcription: pendingSpeechAction.transcription)
    case .undo:
      await performUndo(
        evidence: evidence(for: pendingSpeechAction.transcription)
      )
    case .correction:
      isShowingCorrection = true
    }
  }

  func rejectPendingSpeechAction() {
    if let pendingSpeechAction {
      lastActionDescription = "Ignored: \(pendingSpeechAction.transcription.text)"
    }
    pendingSpeechAction = nil
  }

  func requestCorrectionForPendingSpeechAction() {
    pendingSpeechAction = nil
    isShowingCorrection = true
  }

  func ingestFinalTranscriptForTesting(
    _ text: String,
    confidence: Double = 0.99,
    providerID: String = "test.local"
  ) async {
    await handleTranscription(
      SpeechTranscription(
        text: text,
        confidence: confidence,
        isFinal: true,
        providerID: providerID
      )
    )
  }

  func persist() async throws {
    try await repository.save(timeline)
  }

  private func handleTranscription(_ transcription: SpeechTranscription) async {
    lastTranscript = transcription.text
    lastTranscriptIsFinal = transcription.isFinal
    guard transcription.isFinal else { return }

    let candidate = parser.parse(transcription.text)
    let providerConfidence = transcription.confidence ?? candidate.confidence
    let combinedConfidence = min(candidate.confidence, providerConfidence)
    let shouldConfirm =
      candidate.requiresConfirmation
      || combinedConfidence < speechConfiguration.autoAcceptConfidence

    if candidate.intent == .undo {
      if shouldConfirm {
        pendingSpeechAction = PendingSpeechAction(
          proposal: .undo,
          transcription: transcription,
          confidence: combinedConfidence,
          explanation:
            "Undo changes the score timeline and requires confirmation at this confidence."
        )
      } else {
        await performUndo(evidence: evidence(for: transcription))
      }
      return
    }

    let actionableCandidate = IntentCandidate(
      intent: candidate.intent,
      normalizedText: candidate.normalizedText,
      confidence: candidate.confidence,
      requiresConfirmation: false,
      parserID: candidate.parserID
    )
    let resolution = resolver.resolve(
      shouldConfirm ? actionableCandidate : candidate,
      state: state
    )

    switch resolution {
    case .event(let kind):
      if shouldConfirm {
        pendingSpeechAction = PendingSpeechAction(
          proposal: .event(kind),
          transcription: transcription,
          confidence: combinedConfidence,
          explanation: "Confirm before applying this score action."
        )
      } else {
        await applySpeechEvent(kind, transcription: transcription)
      }
    case .alreadyCurrent:
      lastActionDescription = "Heard the current score; no change"
    case .confirmationRequired(let reason):
      pendingSpeechAction = PendingSpeechAction(
        proposal: .correction,
        transcription: transcription,
        confidence: combinedConfidence,
        explanation: reason
      )
    case .ignored(let reason):
      lastActionDescription = reason
    }
  }

  private func applySpeechEvent(
    _ kind: MatchEventKind,
    transcription: SpeechTranscription
  ) async {
    await apply(
      kind,
      evidence: evidence(for: transcription),
      idempotencyKey: "speech-\(transcription.providerID)-\(transcription.id.uuidString)",
      successDescription: "Voice confirmed: \(transcription.text)"
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
