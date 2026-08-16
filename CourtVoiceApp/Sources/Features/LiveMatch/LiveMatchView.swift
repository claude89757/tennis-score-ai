import CourtVoiceCore
import SwiftUI

struct LiveMatchView: View {
  @Bindable var controller: MatchSessionController
  let onClose: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let isLandscape = proxy.size.width > proxy.size.height

      ZStack {
        LinearGradient(
          colors: [CourtVoiceTheme.courtGreen, CourtVoiceTheme.ink],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        if isLandscape {
          landscapeLayout
        } else {
          portraitLayout
        }
      }
    }
    .preferredColorScheme(.dark)
    .task {
      guard ProcessInfo.processInfo.arguments.contains("-ui-testing") == false else { return }
      await controller.startListening()
    }
    .onDisappear {
      Task { await controller.stopListening() }
    }
    .alert(
      "Scoring error",
      isPresented: Binding(
        get: { controller.lastErrorMessage != nil },
        set: { isPresented in
          if isPresented == false { controller.lastErrorMessage = nil }
        }
      ),
      actions: {
        Button("OK", role: .cancel) { controller.lastErrorMessage = nil }
      },
      message: {
        Text(controller.lastErrorMessage ?? "Unknown error")
      }
    )
  }

  private var portraitLayout: some View {
    ScrollView {
      VStack(spacing: 18) {
        matchToolbar
        ScoreboardView(state: controller.state)
        statusStrip
        VoiceInsightPanel(controller: controller)
      }
      .padding()
    }
  }

  private var landscapeLayout: some View {
    HStack(spacing: 18) {
      VStack(spacing: 16) {
        matchToolbar
        ScoreboardView(state: controller.state)
        statusStrip
      }
      .frame(maxWidth: .infinity)

      ScrollView {
        VoiceInsightPanel(controller: controller)
      }
      .frame(width: 320)
    }
    .padding()
  }

  private var matchToolbar: some View {
    HStack(spacing: 12) {
      Button(action: onClose) {
        Image(systemName: "xmark")
          .frame(width: CourtVoiceTheme.minimumHitTarget, height: CourtVoiceTheme.minimumHitTarget)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Close match")
      .accessibilityIdentifier("live.close")

      VStack(alignment: .leading, spacing: 2) {
        Text("LIVE MATCH")
          .font(.caption.bold())
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
        Text(matchStatusText)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.72))
      }
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, alignment: .leading)
      .layoutPriority(1)

      if let startedAt = controller.state.startedAt {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text(elapsedTime(from: startedAt, to: context.date))
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
        }
        .layoutPriority(0)
      }
    }
  }

  private var statusStrip: some View {
    HStack(spacing: 10) {
      Image(systemName: statusIcon)
        .foregroundStyle(CourtVoiceTheme.tennisYellow)
      Text(controller.lastActionDescription)
        .lineLimit(2)
      Spacer()
      Text(ScoreFormatter.spokenScore(for: controller.state))
        .fontWeight(.semibold)
    }
    .font(.subheadline)
    .foregroundStyle(.white.opacity(0.82))
    .padding(.horizontal, 16)
    .frame(minHeight: 48)
    .background(.white.opacity(0.08), in: Capsule())
  }

  private var statusIcon: String {
    switch controller.state.status {
    case .notStarted: "circle"
    case .inProgress: "record.circle"
    case .paused: "pause.circle"
    case .completed: "checkmark.circle.fill"
    }
  }

  private var matchStatusText: String {
    switch controller.state.status {
    case .notStarted: "Not started"
    case .inProgress: "Agent scoring"
    case .paused: "Paused"
    case .completed(let winner): "Winner: \(controller.state.teams[winner].displayName)"
    }
  }

  private func elapsedTime(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start)))
    return String(
      format: "%02d:%02d:%02d",
      seconds / 3_600,
      (seconds % 3_600) / 60,
      seconds % 60
    )
  }
}
