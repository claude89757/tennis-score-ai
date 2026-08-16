import CourtVoiceCore
import SwiftUI

struct LiveMatchView: View {
  @Bindable var controller: MatchSessionController
  let onClose: () -> Void

  @State private var isShowingEndMatchConfirmation = false

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
    .onDisappear {
      Task { await controller.stopListening() }
    }
    .sheet(isPresented: $controller.isShowingCorrection) {
      ScoreCorrectionView(state: controller.state) { correction in
        Task { await controller.applyCorrection(correction) }
      }
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
    .confirmationDialog(
      "End this match?",
      isPresented: $isShowingEndMatchConfirmation,
      titleVisibility: .visible
    ) {
      Button("Declare \(controller.state.teams.home.displayName) winner") {
        Task { await controller.endMatch(winner: .home) }
      }
      Button("Declare \(controller.state.teams.away.displayName) winner") {
        Task { await controller.endMatch(winner: .away) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Use this only for retirement, walkover, or an intentionally shortened match.")
    }
  }

  private var portraitLayout: some View {
    ScrollView {
      VStack(spacing: 18) {
        matchToolbar
        ScoreboardView(state: controller.state)
        statusStrip
        voicePanel
        manualScoringControls
        utilityControls
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
        VStack(spacing: 14) {
          voicePanel
          manualScoringControls
          utilityControls
        }
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

      Menu {
        Button("Correct score", systemImage: "slider.horizontal.3") {
          controller.isShowingCorrection = true
        }
        Button("End match", systemImage: "flag.checkered") {
          isShowingEndMatchConfirmation = true
        }
        Button("Close", systemImage: "xmark") {
          onClose()
        }
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: CourtVoiceTheme.minimumHitTarget, height: CourtVoiceTheme.minimumHitTarget)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("More match actions")
    }
  }

  private var statusStrip: some View {
    HStack(spacing: 10) {
      Image(systemName: statusIcon)
        .foregroundStyle(CourtVoiceTheme.tennisYellow)
      Text(controller.lastActionDescription)
        .lineLimit(1)
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

  private var voicePanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image(systemName: speechStateIcon)
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
        Text(controller.speechState.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
        Spacer()
      }

      Text(
        controller.lastTranscript.isEmpty
          ? "Start voice scoring when the phone is positioned near the court. Manual controls always remain active."
          : "“\(controller.lastTranscript)”"
      )
      .font(controller.lastTranscript.isEmpty ? .footnote : .body.weight(.medium))
      .foregroundStyle(.white.opacity(0.76))
      .lineLimit(4)

      if let pending = controller.pendingSpeechAction {
        VStack(alignment: .leading, spacing: 10) {
          Text("Confirmation required")
            .font(.caption.bold())
            .foregroundStyle(CourtVoiceTheme.warning)
          Text(pending.explanation)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.72))

          HStack {
            Button("Ignore") {
              controller.rejectPendingSpeechAction()
            }
            .buttonStyle(.bordered)

            if pending.proposal == .correction {
              Button("Correct") {
                controller.requestCorrectionForPendingSpeechAction()
              }
              .buttonStyle(.borderedProminent)
              .tint(CourtVoiceTheme.warning)
              .foregroundStyle(CourtVoiceTheme.ink)
            } else {
              Button("Confirm") {
                Task { await controller.confirmPendingSpeechAction() }
              }
              .buttonStyle(.borderedProminent)
              .tint(CourtVoiceTheme.tennisYellow)
              .foregroundStyle(CourtVoiceTheme.ink)
            }
          }
        }
        .padding(12)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
      }

      Button {
        Task {
          if controller.isListening {
            await controller.stopListening()
          } else {
            await controller.startListening()
          }
        }
      } label: {
        Label(
          controller.isListening ? "Stop listening" : "Start voice scoring",
          systemImage: controller.isListening ? "mic.slash.fill" : "mic.fill"
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
      }
      .buttonStyle(.borderedProminent)
      .tint(controller.isListening ? .white : CourtVoiceTheme.tennisYellow)
      .foregroundStyle(CourtVoiceTheme.ink)
      .disabled(controller.state.status != .inProgress)
      .accessibilityIdentifier("live.listen")
    }
    .padding(16)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
  }

  private var manualScoringControls: some View {
    VStack(spacing: 12) {
      Text("AWARD POINT")
        .font(.caption.bold())
        .foregroundStyle(.white.opacity(0.55))

      scoreButton(side: .home)
      scoreButton(side: .away)
    }
    .padding(16)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
  }

  private func scoreButton(side: TeamSide) -> some View {
    Button {
      Task { await controller.awardPoint(to: side) }
    } label: {
      HStack {
        Image(systemName: "plus.circle.fill")
        Text(controller.state.teams[side].displayName)
          .lineLimit(1)
        Spacer()
        Text("+1")
          .monospacedDigit()
      }
      .font(.headline)
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 58)
    }
    .buttonStyle(.borderedProminent)
    .tint(side == .home ? CourtVoiceTheme.tennisYellow : .white)
    .foregroundStyle(CourtVoiceTheme.ink)
    .disabled(controller.state.status != .inProgress)
    .accessibilityIdentifier("live.award.\(side.rawValue)")
  }

  private var utilityControls: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Button {
          Task { await controller.undo() }
        } label: {
          Label("Undo", systemImage: "arrow.uturn.backward")
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("live.undo")

        Button {
          Task { await controller.togglePause() }
        } label: {
          Label(pauseButtonTitle, systemImage: pauseButtonIcon)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.bordered)
      }

      Menu {
        Button(controller.state.teams.home.displayName) {
          Task { await controller.changeServer(to: .home) }
        }
        Button(controller.state.teams.away.displayName) {
          Task { await controller.changeServer(to: .away) }
        }
      } label: {
        Label("Change server", systemImage: "figure.tennis")
          .frame(maxWidth: .infinity)
          .frame(minHeight: 50)
      }
      .buttonStyle(.bordered)

      Button {
        controller.isShowingCorrection = true
      } label: {
        Label("Correct score", systemImage: "slider.horizontal.3")
          .frame(maxWidth: .infinity)
          .frame(minHeight: 50)
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("live.correct")
    }
    .foregroundStyle(.white)
  }

  private var speechStateIcon: String {
    switch controller.speechState {
    case .idle: "mic.slash"
    case .requestingPermission: "hand.raised.fill"
    case .preparing: "ellipsis.circle"
    case .listening: "waveform.circle.fill"
    case .processing: "sparkles"
    case .interrupted: "pause.circle"
    case .failed: "exclamationmark.triangle.fill"
    }
  }

  private var pauseButtonTitle: String {
    controller.state.status == .paused ? "Resume" : "Pause"
  }

  private var pauseButtonIcon: String {
    controller.state.status == .paused ? "play.fill" : "pause.fill"
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
    case .inProgress: "Scoring in progress"
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
