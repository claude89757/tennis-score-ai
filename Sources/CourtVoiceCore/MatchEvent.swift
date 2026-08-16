import Foundation

public enum MatchEventKind: Codable, Equatable, Sendable {
    case matchStarted
    case pointAwarded(TeamSide)
    case letCalled
    case scoreCorrected(ScoreCorrection)
    case serverChanged(TeamSide)
    case matchPaused
    case matchResumed
    case matchEnded(winner: TeamSide)
    case eventRevoked(eventID: UUID)
}

public struct MatchEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let occurredAt: Date
    public let kind: MatchEventKind
    public let evidence: ScoreEvidence
    public let idempotencyKey: String?

    public init(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        kind: MatchEventKind,
        evidence: ScoreEvidence,
        idempotencyKey: String? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.kind = kind
        self.evidence = evidence
        self.idempotencyKey = idempotencyKey
    }
}

public struct MatchTimeline: Codable, Equatable, Sendable {
    public var initialState: MatchState
    public private(set) var events: [MatchEvent]

    public init(initialState: MatchState, events: [MatchEvent] = []) {
        self.initialState = initialState
        self.events = events
    }

    public var currentState: MatchState {
        MatchReducer.replay(initialState: initialState, events: events)
    }

    public mutating func append(_ event: MatchEvent) throws {
        if let key = event.idempotencyKey,
           events.contains(where: { $0.idempotencyKey == key }) {
            throw MatchRulesError.duplicateIdempotencyKey(key)
        }

        _ = try MatchReducer.apply(event, to: currentState)
        events.append(event)
    }

    @discardableResult
    public mutating func revokeLastMutableEvent(
        evidence: ScoreEvidence = ScoreEvidence(source: .manual)
    ) throws -> MatchEvent {
        let revokedIDs = Set(events.compactMap { event -> UUID? in
            guard case let .eventRevoked(eventID) = event.kind else { return nil }
            return eventID
        })

        guard let target = events.reversed().first(where: { event in
            guard revokedIDs.contains(event.id) == false else { return false }
            switch event.kind {
            case .pointAwarded, .letCalled, .scoreCorrected, .serverChanged:
                return true
            default:
                return false
            }
        }) else {
            throw MatchRulesError.nothingToUndo
        }

        let undo = MatchEvent(kind: .eventRevoked(eventID: target.id), evidence: evidence)
        events.append(undo)
        return undo
    }
}
