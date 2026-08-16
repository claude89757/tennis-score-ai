import CourtVoiceCore
import Foundation

struct SavedMatch: Codable, Identifiable, Sendable {
  var timeline: MatchTimeline
  var updatedAt: Date

  var id: UUID { timeline.initialState.id }
  var state: MatchState { timeline.currentState }

  init(timeline: MatchTimeline, updatedAt: Date = Date()) {
    self.timeline = timeline
    self.updatedAt = updatedAt
  }
}

struct AppPreferences: Codable, Sendable {
  var hasCompletedOnboarding: Bool
  var speechConfiguration: SpeechConfiguration

  static let initial = AppPreferences(
    hasCompletedOnboarding: false,
    speechConfiguration: .standard
  )

  init(
    hasCompletedOnboarding: Bool,
    speechConfiguration: SpeechConfiguration = .standard
  ) {
    self.hasCompletedOnboarding = hasCompletedOnboarding
    self.speechConfiguration = speechConfiguration
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    hasCompletedOnboarding =
      try container.decodeIfPresent(
        Bool.self,
        forKey: .hasCompletedOnboarding
      ) ?? false
    speechConfiguration =
      try container.decodeIfPresent(
        SpeechConfiguration.self,
        forKey: .speechConfiguration
      ) ?? .standard
  }
}
