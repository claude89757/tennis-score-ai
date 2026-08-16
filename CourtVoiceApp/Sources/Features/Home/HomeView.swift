import CourtVoiceCore
import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.l10n) private var l10n
  @State private var isShowingMatchSetup = false
  @State private var isShowingMediaAnalysis = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          heroCard
          mediaAnalysisCard

          if let recentMatch = appModel.matches.first {
            VStack(alignment: .leading, spacing: 12) {
              Text(l10n.continueAction)
                .font(.title2.bold())
                .foregroundStyle(CourtVoiceTheme.textPrimary)
                .accessibilityIdentifier("home.continue")

              Button {
                appModel.resume(recentMatch)
              } label: {
                MatchSummaryCard(savedMatch: recentMatch)
              }
              .buttonStyle(.plain)
            }
          }

          privacyCard
        }
        .padding()
      }
      .courtVoiceCanvas()
      .navigationTitle("CourtVoice")
      .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Image(systemName: "tennisball.fill")
            .foregroundStyle(CourtVoiceTheme.accent)
            .accessibilityHidden(true)
        }
      }
      .sheet(isPresented: $isShowingMatchSetup) {
        MatchSetupView { draft in
          Task { await appModel.startMatch(from: draft) }
        }
      }
      .sheet(isPresented: $isShowingMediaAnalysis) {
        MediaAnalysisView()
      }
      .refreshable {
        await appModel.refreshMatches()
      }
    }
  }

  private var heroCard: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 8) {
        Text(l10n.homeHeroTitle)
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .foregroundStyle(CourtVoiceTheme.onHero)

        Text(l10n.homeHeroDetail)
          .font(.title3)
          .foregroundStyle(CourtVoiceTheme.onHeroMuted)
      }

      Button {
        isShowingMatchSetup = true
      } label: {
        Label(l10n.startMatch, systemImage: "play.fill")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 56)
      }
      .buttonStyle(.borderedProminent)
      .tint(CourtVoiceTheme.tennisYellow)
      .foregroundStyle(CourtVoiceTheme.ink)
      .clipShape(RoundedRectangle(cornerRadius: CourtVoiceTheme.controlCornerRadius))
      .accessibilityIdentifier("home.startMatch")
    }
    .padding(24)
    .background(
      CourtVoiceTheme.heroGradient,
      in: RoundedRectangle(cornerRadius: 30)
    )
    .shadow(color: CourtVoiceTheme.courtGreen.opacity(0.18), radius: 24, y: 12)
  }

  private var mediaAnalysisCard: some View {
    Button {
      isShowingMediaAnalysis = true
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "film.stack.fill")
          .font(.title2)
          .foregroundStyle(CourtVoiceTheme.accent)
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.analyzeRecordedMatch)
            .font(.headline)
            .foregroundStyle(CourtVoiceTheme.textPrimary)
          Text(l10n.analyzeRecordedMatchDetail)
            .font(.subheadline)
            .foregroundStyle(CourtVoiceTheme.textSecondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(CourtVoiceTheme.textTertiary)
      }
      .courtVoiceCard()
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("home.analyzeMedia")
  }

  private var privacyCard: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "lock.shield.fill")
        .font(.title2)
        .foregroundStyle(CourtVoiceTheme.accent)

      VStack(alignment: .leading, spacing: 5) {
        Text(l10n.privateByDefault)
          .font(.headline)
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        Text(l10n.privateByDefaultDetail)
          .font(.subheadline)
          .foregroundStyle(CourtVoiceTheme.textSecondary)
      }
    }
    .courtVoiceCard()
  }
}

struct MatchSummaryCard: View {
  let savedMatch: SavedMatch
  @Environment(\.l10n) private var l10n

  var body: some View {
    let state = savedMatch.state

    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(state.teams.home.displayName)
          Text(state.teams.away.displayName)
        }
        .font(.headline)
        .foregroundStyle(CourtVoiceTheme.textPrimary)

        Spacer()

        VStack(alignment: .trailing, spacing: 3) {
          Text("\(state.setsWon.home)")
          Text("\(state.setsWon.away)")
        }
        .font(.title3.monospacedDigit().bold())
        .foregroundStyle(CourtVoiceTheme.textPrimary)
      }

      HStack {
        Label(statusText(state.status), systemImage: matchStatusIcon(state.status))
        Spacer()
        Text(savedMatch.updatedAt, style: .relative)
      }
      .font(.caption)
      .foregroundStyle(CourtVoiceTheme.textSecondary)
    }
    .courtVoiceCard()
  }

  private func statusText(_ status: MatchStatus) -> String {
    switch status {
    case .notStarted: l10n.matchStatusNotStarted
    case .inProgress: l10n.matchStatusInProgress
    case .paused: l10n.matchStatusPaused
    case .completed: l10n.matchStatusCompleted
    }
  }

  private func matchStatusIcon(_ status: MatchStatus) -> String {
    switch status {
    case .notStarted: "circle"
    case .inProgress: "play.circle.fill"
    case .paused: "pause.circle.fill"
    case .completed: "checkmark.circle.fill"
    }
  }
}
