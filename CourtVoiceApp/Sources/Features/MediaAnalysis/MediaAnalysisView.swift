import CourtVoiceCore
import SwiftUI
import UniformTypeIdentifiers

struct MediaAnalysisView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss

  @State private var viewModel = MediaAnalysisViewModel()
  @State private var draft = MatchConfigurationDraft()
  @State private var isShowingImporter = false
  @State private var saveMessage: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          introductionCard
          matchIdentityCard
          importCard

          if let analysis = viewModel.analysis {
            resultCard(analysis)
          }
        }
        .padding()
      }
      .background(CourtVoiceTheme.ivory.ignoresSafeArea())
      .navigationTitle("Analyze match media")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            viewModel.cancel()
            dismiss()
          }
        }
      }
      .fileImporter(
        isPresented: $isShowingImporter,
        allowedContentTypes: [.movie, .audio],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls):
          if let sourceURL = urls.first {
            viewModel.analyze(
              sourceURL: sourceURL,
              draft: draft,
              configuration: appModel.preferences.speechConfiguration,
              credentialStore: appModel.credentialStore
            )
          }
        case .failure(let error):
          viewModel.errorMessage = error.localizedDescription
        }
      }
      .alert(
        "CourtVoice",
        isPresented: Binding(
          get: { viewModel.errorMessage != nil || saveMessage != nil },
          set: { presented in
            if presented == false {
              viewModel.errorMessage = nil
              saveMessage = nil
            }
          }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.errorMessage ?? saveMessage ?? "")
      }
    }
  }

  private var introductionCard: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "film.stack.fill")
        .font(.largeTitle)
        .foregroundStyle(CourtVoiceTheme.courtGreen)
      VStack(alignment: .leading, spacing: 6) {
        Text("Create a reviewable score timeline")
          .font(.title2.bold())
        Text(
          "CourtVoice extracts the audio track, transcribes timestamped score calls, and commits only legal transitions. Ambiguous phrases remain visible for review."
        )
        .foregroundStyle(.secondary)
      }
    }
    .courtVoiceCard()
  }

  private var matchIdentityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Match identity")
        .font(.headline)
      TextField("Player or team 1", text: $draft.homeName)
        .textFieldStyle(.roundedBorder)
      TextField("Player or team 2", text: $draft.awayName)
        .textFieldStyle(.roundedBorder)
      Picker("First server", selection: $draft.initialServer) {
        Text(draft.homeName).tag(CourtVoiceCore.TeamSide.home)
        Text(draft.awayName).tag(CourtVoiceCore.TeamSide.away)
      }
      .pickerStyle(.segmented)

      LabeledContent(
        "Media provider",
        value: appModel.preferences.speechConfiguration.provider.title
      )
      .font(.footnote)
    }
    .courtVoiceCard()
  }

  private var importCard: some View {
    VStack(spacing: 14) {
      if let sourceFilename = viewModel.sourceFilename {
        Label(sourceFilename, systemImage: "doc.fill")
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
      }

      if isWorking {
        ProgressView(value: viewModel.progress) {
          Text(viewModel.phase.title)
        }
        .tint(CourtVoiceTheme.courtGreen)
        Button("Cancel analysis", role: .cancel) {
          viewModel.cancel()
        }
      } else {
        Button {
          isShowingImporter = true
        } label: {
          Label(
            viewModel.sourceFilename == nil ? "Choose video or audio" : "Choose another file",
            systemImage: "square.and.arrow.down"
          )
          .frame(maxWidth: .infinity)
          .frame(minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(CourtVoiceTheme.courtGreen)
        .disabled(draft.canStart == false)
      }
    }
    .courtVoiceCard()
  }

  private func resultCard(_ analysis: MediaScoreAnalysis) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Transcript review")
          .font(.headline)
        Spacer()
        Text("\(analysis.acceptedCount) accepted · \(analysis.reviewCount) review")
          .font(.caption.weight(.semibold))
          .foregroundStyle(CourtVoiceTheme.courtGreen)
      }

      ScoreboardView(state: analysis.timeline.currentState)

      ForEach(analysis.rows) { row in
        MediaAnalysisRowView(row: row)
      }

      Button {
        Task {
          do {
            try await viewModel.save(to: appModel.matchRepository)
            await appModel.refreshMatches()
            saveMessage = "The accepted score timeline was saved to Match History."
          } catch {
            viewModel.errorMessage = error.localizedDescription
          }
        }
      } label: {
        Label("Save accepted timeline", systemImage: "square.and.arrow.down.fill")
          .frame(maxWidth: .infinity)
          .frame(minHeight: 52)
      }
      .buttonStyle(.borderedProminent)
      .tint(CourtVoiceTheme.courtGreen)
    }
    .courtVoiceCard()
  }

  private var isWorking: Bool {
    switch viewModel.phase {
    case .copying, .extractingAudio, .transcribing, .resolving:
      true
    case .idle, .complete, .failed:
      false
    }
  }
}

private struct MediaAnalysisRowView: View {
  let row: MediaAnalysisRow

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(timestamp)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          Text(outcomeTitle)
            .font(.caption.bold())
            .foregroundStyle(color)
        }
        Text("“\(row.utterance.text)”")
          .font(.subheadline.weight(.medium))
        Text(row.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.vertical, 6)
  }

  private var timestamp: String {
    let seconds = max(0, Int(row.utterance.startTime))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  private var outcomeTitle: String {
    switch row.outcome {
    case .accepted: "ACCEPTED"
    case .needsReview: "REVIEW"
    case .ignored: "IGNORED"
    case .rejected: "REJECTED"
    }
  }

  private var icon: String {
    switch row.outcome {
    case .accepted: "checkmark.circle.fill"
    case .needsReview: "questionmark.circle.fill"
    case .ignored: "minus.circle.fill"
    case .rejected: "xmark.octagon.fill"
    }
  }

  private var color: Color {
    switch row.outcome {
    case .accepted: CourtVoiceTheme.courtGreen
    case .needsReview: CourtVoiceTheme.warning
    case .ignored: .secondary
    case .rejected: .red
    }
  }
}
