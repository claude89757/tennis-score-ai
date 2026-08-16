import CourtVoiceCore
import SwiftUI

struct MatchHistoryView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.l10n) private var l10n

  var body: some View {
    NavigationStack {
      Group {
        if appModel.matches.isEmpty {
          ContentUnavailableView(
            l10n.noMatchesYet,
            systemImage: "tennisball",
            description: Text(l10n.noMatchesDetail)
          )
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        } else {
          List {
            ForEach(appModel.matches) { savedMatch in
              NavigationLink {
                MatchDetailView(savedMatch: savedMatch)
              } label: {
                MatchHistoryRow(savedMatch: savedMatch)
              }
              .listRowBackground(CourtVoiceTheme.cardFill)
              .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if savedMatch.state.isComplete == false {
                  Button {
                    appModel.resume(savedMatch)
                  } label: {
                    Label(l10n.resume, systemImage: "play.fill")
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
          .courtVoiceListChrome()
        }
      }
      .courtVoiceCanvas()
      .navigationTitle(l10n.tabMatches)
      .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
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
  @Environment(\.l10n) private var l10n

  var body: some View {
    let state = savedMatch.state
    HStack(spacing: 14) {
      VStack(spacing: 4) {
        Text("\(state.setsWon.home)")
        Divider().frame(width: 22)
        Text("\(state.setsWon.away)")
      }
      .font(.title3.bold().monospacedDigit())
      .foregroundStyle(CourtVoiceTheme.accent)

      VStack(alignment: .leading, spacing: 5) {
        Text(state.teams.home.displayName)
          .font(.headline)
          .foregroundStyle(CourtVoiceTheme.textPrimary)
          .accessibilityIdentifier("history.homeName")
        Text(state.teams.away.displayName)
          .font(.headline)
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        Text(savedMatch.updatedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption)
          .foregroundStyle(CourtVoiceTheme.textSecondary)
      }

      Spacer()

      if state.isComplete == false {
        Text(l10n.liveBadge)
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
  @Environment(\.l10n) private var l10n

  @State private var exportURL: URL?
  @State private var exportError: String?

  var body: some View {
    let state = savedMatch.state

    ScrollView {
      VStack(spacing: 20) {
        ScoreboardView(state: state)

        VStack(alignment: .leading, spacing: 14) {
          detailRow(l10n.format, value: formatDescription(state.format))
          detailRow(l10n.events, value: "\(savedMatch.timeline.events.count)")
          detailRow(
            l10n.totalPoints, value: "\(state.totalPointsWon.home)–\(state.totalPointsWon.away)")
          if let startedAt = state.startedAt {
            detailRow(l10n.started, value: startedAt.formatted(date: .abbreviated, time: .shortened))
          }
        }
        .courtVoiceCard()

        if let exportURL {
          ShareLink(item: exportURL) {
            Label(l10n.shareMatchJSON, systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity)
              .frame(minHeight: 52)
          }
          .buttonStyle(.borderedProminent)
          .tint(CourtVoiceTheme.accent)
          .foregroundStyle(CourtVoiceTheme.onAccent)
        } else {
          Button {
            do {
              exportURL = try MatchExporter.makeJSONFile(savedMatch.timeline)
            } catch {
              exportError = error.localizedDescription
            }
          } label: {
            Label(l10n.prepareMatchExport, systemImage: "doc.badge.arrow.up")
              .frame(maxWidth: .infinity)
              .frame(minHeight: 52)
          }
          .buttonStyle(.borderedProminent)
          .tint(CourtVoiceTheme.accent)
          .foregroundStyle(CourtVoiceTheme.onAccent)
        }
      }
      .padding()
    }
    .courtVoiceCanvas()
    .navigationTitle(l10n.matchDetails)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .alert(
      l10n.exportFailed,
      isPresented: Binding(
        get: { exportError != nil },
        set: { if $0 == false { exportError = nil } }
      )
    ) {
      Button(l10n.ok, role: .cancel) { exportError = nil }
    } message: {
      Text(exportError ?? l10n.unknownError)
    }
  }

  private func detailRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title).foregroundStyle(CourtVoiceTheme.textSecondary)
      Spacer()
      Text(value)
        .fontWeight(.medium)
        .foregroundStyle(CourtVoiceTheme.textPrimary)
    }
  }

  private func formatDescription(_ format: MatchFormat) -> String {
    l10n.formatDescription(
      isSingles: format.discipline == .singles,
      bestOfSets: format.bestOfSets,
      isAdvantage: format.gameScoring == .advantage
    )
  }
}
