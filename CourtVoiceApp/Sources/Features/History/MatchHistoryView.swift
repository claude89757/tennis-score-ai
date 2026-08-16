import CourtVoiceCore
import SwiftUI

struct MatchHistoryView: View {
  @Environment(AppModel.self) private var appModel

  var body: some View {
    NavigationStack {
      Group {
        if appModel.matches.isEmpty {
          ContentUnavailableView(
            "No matches yet",
            systemImage: "tennisball",
            description: Text("Your locally saved match history will appear here.")
          )
        } else {
          List {
            ForEach(appModel.matches) { savedMatch in
              NavigationLink {
                MatchDetailView(savedMatch: savedMatch)
              } label: {
                MatchHistoryRow(savedMatch: savedMatch)
              }
              .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if savedMatch.state.isComplete == false {
                  Button {
                    appModel.resume(savedMatch)
                  } label: {
                    Label("Resume", systemImage: "play.fill")
                  }
                  .tint(CourtVoiceTheme.courtGreen)
                }
              }
            }
            .onDelete { offsets in
              Task { await appModel.deleteMatches(at: offsets) }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Matches")
      .refreshable { await appModel.refreshMatches() }
      .toolbar {
        if appModel.matches.isEmpty == false {
          EditButton()
        }
      }
    }
  }
}

private struct MatchHistoryRow: View {
  let savedMatch: SavedMatch

  var body: some View {
    let state = savedMatch.state
    HStack(spacing: 14) {
      VStack(spacing: 4) {
        Text("\(state.setsWon.home)")
        Divider().frame(width: 22)
        Text("\(state.setsWon.away)")
      }
      .font(.title3.bold().monospacedDigit())
      .foregroundStyle(CourtVoiceTheme.courtGreen)

      VStack(alignment: .leading, spacing: 5) {
        Text(state.teams.home.displayName)
          .font(.headline)
        Text(state.teams.away.displayName)
          .font(.headline)
        Text(savedMatch.updatedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if state.isComplete == false {
        Text("LIVE")
          .font(.caption2.bold())
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(CourtVoiceTheme.tennisYellow, in: Capsule())
          .foregroundStyle(CourtVoiceTheme.ink)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct MatchDetailView: View {
  let savedMatch: SavedMatch

  @State private var exportURL: URL?
  @State private var exportError: String?

  var body: some View {
    let state = savedMatch.state

    ScrollView {
      VStack(spacing: 20) {
        ScoreboardView(state: state)

        VStack(alignment: .leading, spacing: 14) {
          detailRow("Format", value: formatDescription(state.format))
          detailRow("Events", value: "\(savedMatch.timeline.events.count)")
          detailRow(
            "Total points", value: "\(state.totalPointsWon.home)–\(state.totalPointsWon.away)")
          if let startedAt = state.startedAt {
            detailRow("Started", value: startedAt.formatted(date: .abbreviated, time: .shortened))
          }
        }
        .courtVoiceCard()

        if let exportURL {
          ShareLink(item: exportURL) {
            Label("Share match JSON", systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity)
              .frame(minHeight: 52)
          }
          .buttonStyle(.borderedProminent)
          .tint(CourtVoiceTheme.courtGreen)
        } else {
          Button {
            do {
              exportURL = try MatchExporter.makeJSONFile(savedMatch.timeline)
            } catch {
              exportError = error.localizedDescription
            }
          } label: {
            Label("Prepare match export", systemImage: "doc.badge.arrow.up")
              .frame(maxWidth: .infinity)
              .frame(minHeight: 52)
          }
          .buttonStyle(.borderedProminent)
          .tint(CourtVoiceTheme.courtGreen)
        }
      }
      .padding()
    }
    .background(CourtVoiceTheme.ivory.ignoresSafeArea())
    .navigationTitle("Match details")
    .navigationBarTitleDisplayMode(.inline)
    .alert(
      "Export failed",
      isPresented: Binding(
        get: { exportError != nil },
        set: { if $0 == false { exportError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { exportError = nil }
    } message: {
      Text(exportError ?? "Unknown error")
    }
  }

  private func detailRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title).foregroundStyle(.secondary)
      Spacer()
      Text(value).fontWeight(.medium)
    }
  }

  private func formatDescription(_ format: MatchFormat) -> String {
    let discipline = format.discipline == .singles ? "Singles" : "Doubles"
    let scoring = format.gameScoring == .advantage ? "Advantage" : "No-Ad"
    return "\(discipline), best of \(format.bestOfSets), \(scoring)"
  }
}
