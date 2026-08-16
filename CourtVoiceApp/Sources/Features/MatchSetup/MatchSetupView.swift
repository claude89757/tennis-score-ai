import CourtVoiceCore
import SwiftUI

struct MatchSetupView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.l10n) private var l10n

  let onStart: (MatchConfigurationDraft) -> Void

  @State private var draft = MatchConfigurationDraft()
  @State private var didApplyLanguage = false

  var body: some View {
    NavigationStack {
      Form {
        Section(l10n.players) {
          TextField(l10n.playerOrTeam1, text: $draft.homeName)
            .textInputAutocapitalization(.words)
          TextField(l10n.playerOrTeam2, text: $draft.awayName)
            .textInputAutocapitalization(.words)

          Picker(l10n.discipline, selection: $draft.discipline) {
            Text(l10n.singles).tag(MatchDiscipline.singles)
            Text(l10n.doubles).tag(MatchDiscipline.doubles)
          }
          .pickerStyle(.segmented)

          if draft.discipline == .doubles {
            TextField(l10n.team1Members, text: $draft.homeMembers)
            TextField(l10n.team2Members, text: $draft.awayMembers)
          }
        }

        Section(l10n.matchFormat) {
          Picker(l10n.sets, selection: $draft.bestOfSets) {
            Text(l10n.oneSet).tag(1)
            Text(l10n.bestOf3).tag(3)
            Text(l10n.bestOf5).tag(5)
          }

          Picker(l10n.gameScoring, selection: $draft.gameScoring) {
            Text(l10n.advantage).tag(GameScoringRule.advantage)
            Text(l10n.noAd).tag(GameScoringRule.noAd)
          }

          Toggle(l10n.decidingTiebreak, isOn: $draft.usesDecidingMatchTiebreak)
        }

        Section(l10n.firstServer) {
          Picker(l10n.server, selection: $draft.initialServer) {
            Text(draft.homeName).tag(TeamSide.home)
            Text(draft.awayName).tag(TeamSide.away)
          }
          .pickerStyle(.segmented)
        }

        Section {
          Label(l10n.matchSetupHint, systemImage: "checkmark.shield")
            .font(.footnote)
            .foregroundStyle(CourtVoiceTheme.textSecondary)
        }
      }
      .courtVoiceListChrome()
      .navigationTitle(l10n.newMatch)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(l10n.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(l10n.start) {
            onStart(draft)
            dismiss()
          }
          .disabled(draft.canStart == false)
          .fontWeight(.semibold)
          .accessibilityIdentifier("matchSetup.start")
        }
      }
      .onAppear {
        guard didApplyLanguage == false else { return }
        draft = .standard(language: l10n.language)
        didApplyLanguage = true
      }
    }
  }
}
