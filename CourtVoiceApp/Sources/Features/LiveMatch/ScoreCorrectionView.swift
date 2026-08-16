import CourtVoiceCore
import SwiftUI

struct ScoreCorrectionView: View {
  @Environment(\.dismiss) private var dismiss

  let state: MatchState
  let onSave: (ScoreCorrection) -> Void

  @State private var homeGames: Int
  @State private var awayGames: Int
  @State private var homePoints: Int
  @State private var awayPoints: Int
  @State private var server: TeamSide

  init(state: MatchState, onSave: @escaping (ScoreCorrection) -> Void) {
    self.state = state
    self.onSave = onSave
    _homeGames = State(initialValue: state.currentGames.home)
    _awayGames = State(initialValue: state.currentGames.away)
    _homePoints = State(initialValue: state.currentGame.rawPoints.home)
    _awayPoints = State(initialValue: state.currentGame.rawPoints.away)
    _server = State(initialValue: state.server)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Current set games") {
          scoreStepper(
            title: state.teams.home.displayName,
            value: $homeGames,
            range: 0...7
          )
          scoreStepper(
            title: state.teams.away.displayName,
            value: $awayGames,
            range: 0...7
          )
        }

        Section(state.currentGame.isTiebreak ? "Tiebreak points" : "Current game points") {
          scoreStepper(
            title: state.teams.home.displayName,
            value: $homePoints,
            range: state.currentGame.isTiebreak ? 0...99 : 0...4
          )
          scoreStepper(
            title: state.teams.away.displayName,
            value: $awayPoints,
            range: state.currentGame.isTiebreak ? 0...99 : 0...4
          )

          if state.currentGame.isTiebreak == false {
            Text(
              "0, 1, 2, 3 and 4 represent Love, 15, 30, 40 and Advantage. Invalid combinations are rejected by the rules engine."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
        }

        Section("Server") {
          Picker("Server", selection: $server) {
            Text(state.teams.home.displayName).tag(TeamSide.home)
            Text(state.teams.away.displayName).tag(TeamSide.away)
          }
          .pickerStyle(.segmented)
        }
      }
      .navigationTitle("Correct score")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(
              ScoreCorrection(
                completedSets: state.completedSets,
                currentGames: SidePair(home: homeGames, away: awayGames),
                currentGame: GameState(
                  rawPoints: SidePair(home: homePoints, away: awayPoints),
                  isTiebreak: state.currentGame.isTiebreak,
                  tiebreakTarget: state.currentGame.tiebreakTarget,
                  tiebreakStartingServer: state.currentGame.tiebreakStartingServer
                ),
                server: server
              )
            )
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
  }

  private func scoreStepper(
    title: String,
    value: Binding<Int>,
    range: ClosedRange<Int>
  ) -> some View {
    Stepper(value: value, in: range) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value.wrappedValue)")
          .font(.headline.monospacedDigit())
      }
    }
  }
}
