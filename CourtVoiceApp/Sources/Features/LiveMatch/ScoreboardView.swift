import CourtVoiceCore
import SwiftUI

struct ScoreboardView: View {
  let state: MatchState

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(.white.opacity(0.18))
      teamRow(side: .home)
      Divider().overlay(.white.opacity(0.18))
      teamRow(side: .away)
    }
    .background(CourtVoiceTheme.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 28))
    .overlay {
      RoundedRectangle(cornerRadius: 28)
        .stroke(.white.opacity(0.12), lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Tennis scoreboard")
    .accessibilityIdentifier("live.scoreboard")
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text("PLAYER")
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(Array(state.completedSets.indices), id: \.self) { index in
        Text("S\(index + 1)")
          .frame(width: 42)
      }
      Text("GAME")
        .frame(width: 58)
      Text(state.currentGame.isTiebreak ? "TB" : "POINT")
        .frame(width: 74)
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(.white.opacity(0.58))
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
  }

  private func teamRow(side: TeamSide) -> some View {
    HStack(spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: state.server == side ? "circle.fill" : "circle")
          .font(.caption)
          .foregroundStyle(
            state.server == side ? CourtVoiceTheme.tennisYellow : .white.opacity(0.22)
          )
          .accessibilityLabel(state.server == side ? "Serving" : "Receiving")

        Text(state.teams[side].displayName)
          .lineLimit(1)
          .minimumScaleFactor(0.65)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      ForEach(Array(state.completedSets.enumerated()), id: \.element.id) { _, completedSet in
        Text("\(completedSet.games[side])")
          .frame(width: 42)
      }

      Text("\(state.currentGames[side])")
        .frame(width: 58)

      Text(pointText(for: side))
        .foregroundStyle(CourtVoiceTheme.tennisYellow)
        .frame(width: 74)
    }
    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
    .foregroundStyle(.white)
    .padding(.horizontal, 20)
    .padding(.vertical, 22)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityScore(for: side))
  }

  private func pointText(for side: TeamSide) -> String {
    switch ScoreFormatter.pointDisplay(for: state) {
    case .regular(let home, let away):
      return side == .home ? home : away
    case .deuce:
      return side == .home ? "40" : "40"
    case .advantage(let advantageSide):
      return advantageSide == side ? "AD" : "40"
    case .tiebreak(let home, let away):
      return "\(side == .home ? home : away)"
    }
  }

  private func accessibilityScore(for side: TeamSide) -> String {
    let team = state.teams[side].displayName
    let server = state.server == side ? "serving" : "receiving"
    return "\(team), \(server), \(state.currentGames[side]) games, \(pointText(for: side)) points"
  }
}
