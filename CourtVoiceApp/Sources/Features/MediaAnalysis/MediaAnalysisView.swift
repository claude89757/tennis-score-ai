import CourtVoiceCore
import SwiftUI
import UniformTypeIdentifiers

struct MediaAnalysisView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.l10n) private var l10n

  @State private var viewModel = MediaAnalysisViewModel()
  @State private var draft = MatchConfigurationDraft()
  @State private var isShowingImporter = false
  @State private var saveMessage: String?
  @State private var didApplyLanguage = false

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
      .courtVoiceCanvas()
      .navigationTitle(l10n.analyzeMatchMedia)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(l10n.close) {
            viewModel.cancel()
            dismiss()
          }
          .accessibilityIdentifier("media.close")
        }
      }
      .onAppear {
        guard didApplyLanguage == false else { return }
        draft = .standard(language: l10n.language)
        didApplyLanguage = true
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
        Button(l10n.ok, role: .cancel) {}
      } message: {
        Text(viewModel.errorMessage ?? saveMessage ?? "")
      }
    }
  }

  private var introductionCard: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "film.stack.fill")
        .font(.largeTitle)
        .foregroundStyle(CourtVoiceTheme.accent)
      VStack(alignment: .leading, spacing: 6) {
        Text(l10n.createReviewableTimeline)
          .font(.title2.bold())
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        Text(l10n.mediaIntro)
          .foregroundStyle(CourtVoiceTheme.textSecondary)
      }
    }
    .courtVoiceCard()
  }

  private var matchIdentityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(l10n.matchIdentity)
        .font(.headline)
        .foregroundStyle(CourtVoiceTheme.textPrimary)
      TextField(l10n.playerOrTeam1, text: $draft.homeName)
        .textFieldStyle(.roundedBorder)
      TextField(l10n.playerOrTeam2, text: $draft.awayName)
        .textFieldStyle(.roundedBorder)
      Picker(l10n.firstServer, selection: $draft.initialServer) {
        Text(draft.homeName).tag(CourtVoiceCore.TeamSide.home)
        Text(draft.awayName).tag(CourtVoiceCore.TeamSide.away)
      }
      .pickerStyle(.segmented)

      LabeledContent(
        l10n.mediaProvider,
        value: l10n.providerTitle(appModel.preferences.speechConfiguration.provider)
      )
      .font(.footnote)
      .foregroundStyle(CourtVoiceTheme.textSecondary)
    }
    .courtVoiceCard()
  }

  private var importCard: some View {
    VStack(spacing: 14) {
      if let sourceFilename = viewModel.sourceFilename {
        Label(sourceFilename, systemImage: "doc.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(CourtVoiceTheme.textPrimary)
          .lineLimit(1)
      }

      if isWorking {
        ProgressView(value: viewModel.progress) {
          Text(l10n.mediaPhase(viewModel.phase))
            .foregroundStyle(CourtVoiceTheme.textSecondary)
        }
        .tint(CourtVoiceTheme.accent)
        Button(l10n.cancelAnalysis, role: .cancel) {
          viewModel.cancel()
        }
      } else {
        Button {
          isShowingImporter = true
        } label: {
          Label(
            viewModel.sourceFilename == nil ? l10n.chooseVideoOrAudio : l10n.chooseAnotherFile,
            systemImage: "square.and.arrow.down"
          )
          .frame(maxWidth: .infinity)
          .frame(minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(CourtVoiceTheme.accent)
        .foregroundStyle(CourtVoiceTheme.onAccent)
        .disabled(draft.canStart == false)
      }
    }
    .courtVoiceCard()
  }

  private func resultCard(_ analysis: MediaScoreAnalysis) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(l10n.transcriptReview)
          .font(.headline)
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        Spacer()
        Text(l10n.acceptedAndReview(accepted: analysis.acceptedCount, review: analysis.reviewCount))
          .font(.caption.weight(.semibold))
          .foregroundStyle(CourtVoiceTheme.accent)
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
            saveMessage = l10n.timelineSaved
          } catch {
            viewModel.errorMessage = error.localizedDescription
          }
        }
      } label: {
        Label(l10n.saveAcceptedTimeline, systemImage: "square.and.arrow.down.fill")
          .frame(maxWidth: .infinity)
          .frame(minHeight: 52)
      }
      .buttonStyle(.borderedProminent)
      .tint(CourtVoiceTheme.accent)
      .foregroundStyle(CourtVoiceTheme.onAccent)
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
  @Environment(\.l10n) private var l10n

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(timestamp)
            .font(.caption.monospacedDigit())
            .foregroundStyle(CourtVoiceTheme.textSecondary)
          Text(l10n.mediaOutcome(row.outcome))
            .font(.caption.bold())
            .foregroundStyle(color)
        }
        Text("“\(row.utterance.text)”")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(CourtVoiceTheme.textPrimary)
        Text(row.detail)
          .font(.caption)
          .foregroundStyle(CourtVoiceTheme.textSecondary)
      }
      Spacer()
    }
    .padding(.vertical, 6)
  }

  private var timestamp: String {
    let seconds = max(0, Int(row.utterance.startTime))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
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
    case .accepted: CourtVoiceTheme.accent
    case .needsReview: CourtVoiceTheme.warning
    case .ignored: CourtVoiceTheme.textSecondary
    case .rejected: CourtVoiceTheme.danger
    }
  }
}
