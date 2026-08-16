import CourtVoiceCore
import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var appModel
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
              Text("Continue")
                .font(.title2.bold())

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
      .background(CourtVoiceTheme.ivory.ignoresSafeArea())
      .navigationTitle("CourtVoice")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Image(systemName: "tennisball.fill")
            .foregroundStyle(CourtVoiceTheme.courtGreen)
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
        Text("Score without breaking your rhythm")
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .foregroundStyle(.white)

        Text(
          "Start a match, then let the voice agent and tennis rules engine keep score. Watch the live board, transcript, and model thinking."
        )
        .font(.title3)
        .foregroundStyle(.white.opacity(0.78))
      }

      Button {
        isShowingMatchSetup = true
      } label: {
        Label("Start match", systemImage: "play.fill")
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
      LinearGradient(
        colors: [CourtVoiceTheme.courtGreenLight, CourtVoiceTheme.courtGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
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
          .foregroundStyle(CourtVoiceTheme.courtGreen)
        VStack(alignment: .leading, spacing: 4) {
          Text("Analyze a recorded match")
            .font(.headline)
            .foregroundStyle(.primary)
          Text("Import video or audio and build a timestamped, rules-checked score draft.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(.secondary)
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
        .foregroundStyle(CourtVoiceTheme.courtGreen)

      VStack(alignment: .leading, spacing: 5) {
        Text("Private by default")
          .font(.headline)
        Text(
          "Match history stays on this device. Raw microphone audio is not stored by the scoring workflow."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
    .courtVoiceCard()
  }
}

struct MatchSummaryCard: View {
  let savedMatch: SavedMatch

  var body: some View {
    let state = savedMatch.state

    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(state.teams.home.displayName)
          Text(state.teams.away.displayName)
        }
        .font(.headline)

        Spacer()

        VStack(alignment: .trailing, spacing: 3) {
          Text("\(state.setsWon.home)")
          Text("\(state.setsWon.away)")
        }
        .font(.title3.monospacedDigit().bold())
      }

      HStack {
        Label(matchStatusText(state.status), systemImage: matchStatusIcon(state.status))
        Spacer()
        Text(savedMatch.updatedAt, style: .relative)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .courtVoiceCard()
  }

  private func matchStatusText(_ status: MatchStatus) -> String {
    switch status {
    case .notStarted: "Not started"
    case .inProgress: "In progress"
    case .paused: "Paused"
    case .completed: "Completed"
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
