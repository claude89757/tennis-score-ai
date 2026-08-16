import CourtVoiceCore
import SwiftUI

struct MatchSetupView: View {
  @Environment(\.dismiss) private var dismiss

  let onStart: (MatchConfigurationDraft) -> Void

  @State private var draft = MatchConfigurationDraft()

  var body: some View {
    NavigationStack {
      Form {
        Section("Players") {
          TextField("Player or team 1", text: $draft.homeName)
            .textInputAutocapitalization(.words)
          TextField("Player or team 2", text: $draft.awayName)
            .textInputAutocapitalization(.words)

          Picker("Discipline", selection: $draft.discipline) {
            Text("Singles").tag(MatchDiscipline.singles)
            Text("Doubles").tag(MatchDiscipline.doubles)
          }
          .pickerStyle(.segmented)

          if draft.discipline == .doubles {
            TextField("Team 1 members, comma-separated", text: $draft.homeMembers)
            TextField("Team 2 members, comma-separated", text: $draft.awayMembers)
          }
        }

        Section("Match format") {
          Picker("Sets", selection: $draft.bestOfSets) {
            Text("1 set").tag(1)
            Text("Best of 3").tag(3)
            Text("Best of 5").tag(5)
          }

          Picker("Game scoring", selection: $draft.gameScoring) {
            Text("Advantage").tag(GameScoringRule.advantage)
            Text("No-Ad").tag(GameScoringRule.noAd)
          }

          Toggle("10-point match tiebreak in deciding set", isOn: $draft.usesDecidingMatchTiebreak)
        }

        Section("First server") {
          Picker("Server", selection: $draft.initialServer) {
            Text(draft.homeName).tag(TeamSide.home)
            Text(draft.awayName).tag(TeamSide.away)
          }
          .pickerStyle(.segmented)
        }

        Section {
          Label(
            "You can always score manually. Voice control is optional and never bypasses the tennis rules engine.",
            systemImage: "checkmark.shield"
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("New match")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Start") {
            onStart(draft)
            dismiss()
          }
          .disabled(draft.canStart == false)
          .fontWeight(.semibold)
        }
      }
    }
  }
}
