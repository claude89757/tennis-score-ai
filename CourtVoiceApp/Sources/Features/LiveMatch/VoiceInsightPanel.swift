import SwiftUI

struct VoiceInsightPanel: View {
  @Bindable var controller: MatchSessionController

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 9) {
        Image(systemName: speechStateIcon)
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
        Text(controller.speechState.title)
          .font(.subheadline.weight(.semibold))
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
          controller.isListening ? "Pause agent" : "Start voice agent",
          systemImage: controller.isListening ? "pause.fill" : "waveform.and.mic"
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

  private var transcriptSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("TRANSCRIPT")
        .font(.caption.bold())
        .foregroundStyle(.white.opacity(0.5))
        .accessibilityIdentifier("live.transcript")

      if controller.transcriptLines.isEmpty {
        Text("The agent will transcribe court calls here as they arrive.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.7))
      } else {
        ForEach(Array(controller.transcriptLines.suffix(5))) { line in
          HStack(alignment: .top, spacing: 8) {
            Text(line.isFinal ? "Final" : "Live")
              .font(.caption2.bold())
              .foregroundStyle(line.isFinal ? CourtVoiceTheme.tennisYellow : .white.opacity(0.55))
              .frame(width: 36, alignment: .leading)
            Text(line.text)
              .font(.body.weight(line.isFinal ? .medium : .regular))
              .foregroundStyle(.white.opacity(line.isFinal ? 0.92 : 0.7))
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
      Text(controller.reasoningPhase.title.uppercased())
        .font(.caption.bold())
        .foregroundStyle(.white.opacity(0.5))
        .accessibilityIdentifier("live.reasoning")

      if controller.reasoningThinking.isEmpty, controller.reasoningAnswer.isEmpty {
        Text("DeepSeek thinking appears here after a final transcript. It can propose an intent; only the rules engine may change the score.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.7))
      } else {
        if controller.reasoningThinking.isEmpty == false {
          Text(controller.reasoningThinking)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(8)
            .accessibilityIdentifier("live.reasoning.thinking")
        }
        if controller.reasoningAnswer.isEmpty == false {
          Text(controller.reasoningAnswer)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(CourtVoiceTheme.tennisYellow.opacity(0.9))
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
