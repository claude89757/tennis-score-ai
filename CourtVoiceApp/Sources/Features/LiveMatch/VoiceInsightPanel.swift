import SwiftUI

struct VoiceInsightPanel: View {
  @Bindable var controller: MatchSessionController
  @Environment(\.l10n) private var l10n

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 9) {
        Image(systemName: speechStateIcon)
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
        Text(l10n.speechState(controller.speechState))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(CourtVoiceTheme.onCourt)
          .lineLimit(2)
          .accessibilityIdentifier("live.speechState")
        Spacer()
      }

      transcriptSection
      reasoningSection

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
          controller.isListening ? l10n.pauseAgent : l10n.startVoiceAgent,
          systemImage: controller.isListening ? "pause.fill" : "waveform.and.mic"
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
      }
      .buttonStyle(.borderedProminent)
      .tint(controller.isListening ? CourtVoiceTheme.onCourt : CourtVoiceTheme.tennisYellow)
      .foregroundStyle(CourtVoiceTheme.ink)
      .disabled(controller.state.status != .inProgress)
      .accessibilityIdentifier("live.listen")
    }
    .padding(16)
    .background(CourtVoiceTheme.courtPanel, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(CourtVoiceTheme.courtPanelStroke, lineWidth: 1)
    }
  }

  private var transcriptSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(l10n.transcript)
        .font(.caption.bold())
        .foregroundStyle(CourtVoiceTheme.onCourtFaint)
        .accessibilityIdentifier("live.transcript")

      if controller.transcriptLines.isEmpty {
        Text(l10n.transcriptEmpty)
          .font(.footnote)
          .foregroundStyle(CourtVoiceTheme.onCourtMuted)
      } else {
        ForEach(Array(controller.transcriptLines.suffix(5))) { line in
          HStack(alignment: .top, spacing: 8) {
            Text(line.isFinal ? l10n.transcriptFinal : l10n.transcriptLive)
              .font(.caption2.bold())
              .foregroundStyle(line.isFinal ? CourtVoiceTheme.tennisYellow : CourtVoiceTheme.onCourtFaint)
              .frame(width: 36, alignment: .leading)
            Text(line.text)
              .font(.body.weight(line.isFinal ? .medium : .regular))
              .foregroundStyle(line.isFinal ? CourtVoiceTheme.onCourt : CourtVoiceTheme.onCourtMuted)
              .accessibilityIdentifier(
                line.id == controller.transcriptLines.last?.id
                  ? "live.transcript.latest"
                  : "live.transcript.line"
              )
          }
        }
      }
    }
  }

  private var reasoningSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(l10n.reasoningPhase(controller.reasoningPhase))
        .font(.caption.bold())
        .foregroundStyle(CourtVoiceTheme.onCourtFaint)
        .accessibilityIdentifier("live.reasoning")

      if controller.reasoningThinking.isEmpty, controller.reasoningAnswer.isEmpty {
        Text(l10n.reasoningEmpty)
          .font(.footnote)
          .foregroundStyle(CourtVoiceTheme.onCourtMuted)
      } else {
        if controller.reasoningThinking.isEmpty == false {
          Text(controller.reasoningThinking)
            .font(.footnote)
            .foregroundStyle(CourtVoiceTheme.onCourtMuted)
            .lineLimit(8)
            .accessibilityIdentifier("live.reasoning.thinking")
        }
        if controller.reasoningAnswer.isEmpty == false {
          Text(controller.reasoningAnswer)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(CourtVoiceTheme.tennisYellow.opacity(0.92))
            .lineLimit(6)
            .accessibilityIdentifier("live.reasoning.answer")
        }
      }
    }
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
}
