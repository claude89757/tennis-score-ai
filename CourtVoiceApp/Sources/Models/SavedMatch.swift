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

  static let initial = AppPreferences(hasCompletedOnboarding: false)
}
