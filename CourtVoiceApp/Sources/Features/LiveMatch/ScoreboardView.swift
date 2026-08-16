import CourtVoiceCore
import SwiftUI

struct ScoreboardView: View {
  let state: MatchState
  @Environment(\.l10n) private var l10n

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(CourtVoiceTheme.courtPanelStroke)
      teamRow(side: .home)
      Divider().overlay(CourtVoiceTheme.courtPanelStroke)
      teamRow(side: .away)
    }
    .background(CourtVoiceTheme.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 28))
    .overlay {
      RoundedRectangle(cornerRadius: 28)
        .stroke(CourtVoiceTheme.courtPanelStroke, lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(l10n.tennisScoreboard)
    .accessibilityIdentifier("live.scoreboard")
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text(l10n.playerColumn)
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(Array(state.completedSets.indices), id: \.self) { index in
        Text("S\(index + 1)")
          .frame(width: 42)
      }
      Text(l10n.gameColumn)
        .frame(width: 58)
      Text(state.currentGame.isTiebreak ? "TB" : l10n.pointColumn)
        .frame(width: 74)
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(CourtVoiceTheme.onCourtFaint)
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
  }

  private func teamRow(side: TeamSide) -> some View {
    HStack(spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: state.server == side ? "circle.fill" : "circle")
          .font(.caption)
          .foregroundStyle(
            state.server == side ? CourtVoiceTheme.tennisYellow : CourtVoiceTheme.onCourtSubtle
          )
          .accessibilityLabel(state.server == side ? l10n.serving : l10n.receiving)

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
    .foregroundStyle(CourtVoiceTheme.onCourt)
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
    l10n.accessibilityScore(
      team: state.teams[side].displayName,
      isServing: state.server == side,
      games: state.currentGames[side],
      points: pointText(for: side)
    )
  }
}
