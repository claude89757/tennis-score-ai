import CourtVoiceCore
import Foundation

struct MatchConfigurationDraft: Equatable {
  var homeName = "Player 1"
  var awayName = "Player 2"
  var homeMembers = ""
  var awayMembers = ""
  var discipline: MatchDiscipline = .singles
  var bestOfSets = 3
  var gameScoring: GameScoringRule = .advantage
  var usesDecidingMatchTiebreak = false
  var initialServer: TeamSide = .home

  var canStart: Bool {
    homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      && awayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  func makeInitialState() -> MatchState {
    let format = MatchFormat(
      discipline: discipline,
      bestOfSets: bestOfSets,
      gameScoring: gameScoring,
      tiebreakTarget: 7,
      decidingSetRule: usesDecidingMatchTiebreak
        ? .matchTiebreak(target: 10)
        : .standardSet
    )

    return MatchState(
      teams: SidePair(
        home: Team(
          displayName: homeName.trimmingCharacters(in: .whitespacesAndNewlines),
          memberNames: splitMembers(homeMembers)
        ),
        away: Team(
          displayName: awayName.trimmingCharacters(in: .whitespacesAndNewlines),
          memberNames: splitMembers(awayMembers)
        )
      ),
      format: format,
      initialServer: initialServer
    )
  }

  private func splitMembers(_ value: String) -> [String] {
    value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
  }
}
