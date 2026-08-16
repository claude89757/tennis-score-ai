import Foundation
import SwiftUI

struct ModelSettingsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.l10n) private var l10n

  @State private var configuration = SpeechConfiguration.standard
  @State private var openAIKey = ""
  @State private var deepgramKey = ""
  @State private var deepseekKey = ""
  @State private var hasOpenAIKey = false
  @State private var hasDeepgramKey = false
  @State private var hasDeepSeekKey = false
  @State private var operationMessage: String?
  @State private var isSaving = false

  var body: some View {
    Form {
      Section(l10n.voiceMode) {
        Picker(l10n.provider, selection: $configuration.provider) {
          ForEach(SpeechProviderKind.allCases) { provider in
            VStack(alignment: .leading) {
              Text(l10n.providerTitle(provider))
              Text(l10n.providerSubtitle(provider))
            }
            .tag(provider)
          }
        }

        Picker(l10n.recognitionLanguage, selection: $configuration.localeIdentifier) {
          Text("简体中文").tag("zh-CN")
          Text("English (US)").tag("en-US")
          Text("한국어").tag("ko-KR")
        }

        VStack(alignment: .leading, spacing: 8) {
          LabeledContent(
            l10n.automaticAcceptance,
            value: configuration.autoAcceptConfidence.formatted(
              .percent.precision(.fractionLength(0)))
          )
          Slider(value: $configuration.autoAcceptConfidence, in: 0.75...0.99, step: 0.01)
          Text(l10n.automaticAcceptanceHint)
            .font(.footnote)
            .foregroundStyle(CourtVoiceTheme.textSecondary)
        }
      }

      Section {
        TextField(l10n.openAIEndpoint, text: $configuration.openAITranscriptionEndpoint)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        TextField(l10n.transcriptionModel, text: $configuration.openAITranscriptionModel)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasOpenAIKey ? l10n.apiKeySavedReplace("OpenAI") : l10n.apiKey,
          text: $openAIKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button(l10n.saveKey) {
            Task { await saveOpenAIKey() }
          }
          .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasOpenAIKey {
            Spacer()
            Button(l10n.remove, role: .destructive) {
              Task { await removeCredential(.openAIAPIKey) }
            }
          }
        }
      } header: {
        Text(l10n.openAIBYOK)
      } footer: {
        Text(l10n.openAIBYOKFooter)
      }

      Section {
        TextField(l10n.model, text: $configuration.deepgramModel)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        TextField(l10n.languageCodeOrMulti, text: $configuration.deepgramLanguage)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasDeepgramKey ? l10n.apiKeySavedReplace("Deepgram") : l10n.apiKey,
          text: $deepgramKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button(l10n.saveKey) {
            Task { await saveDeepgramKey() }
          }
          .disabled(deepgramKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasDeepgramKey {
            Spacer()
            Button(l10n.remove, role: .destructive) {
              Task { await removeCredential(.deepgramAPIKey) }
            }
          }
        }
      } header: {
        Text(l10n.deepgramBYOK)
      } footer: {
        Text(l10n.deepgramFooter)
      }

      Section {
        Toggle(l10n.streamThinking, isOn: $configuration.scoreReasoningEnabled)

        Picker(l10n.model, selection: $configuration.scoreReasoningModel) {
          Text("deepseek-v4-flash").tag("deepseek-v4-flash")
          Text("deepseek-v4-pro").tag("deepseek-v4-pro")
        }

        TextField(l10n.httpsChatEndpoint, text: $configuration.scoreReasoningEndpoint)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasDeepSeekKey ? l10n.apiKeySavedReplace("DeepSeek") : l10n.apiKey,
          text: $deepseekKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button(l10n.saveKey) {
            Task { await saveDeepSeekKey() }
          }
          .disabled(deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasDeepSeekKey {
            Spacer()
            Button(l10n.remove, role: .destructive) {
              Task { await removeCredential(.deepseekAPIKey) }
            }
          }
        }
      } header: {
        Text(l10n.deepSeekReasoning)
      } footer: {
        Text(l10n.deepSeekFooter)
      }

      Section {
        Label(l10n.liveAudioNotStored, systemImage: "lock.shield.fill")
          .foregroundStyle(CourtVoiceTheme.textSecondary)
      }
    }
    .courtVoiceListChrome()
    .navigationTitle(l10n.speechAndAI)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(isSaving ? l10n.saving : l10n.save) {
          Task { await saveConfiguration() }
        }
        .disabled(isSaving)
        .fontWeight(.semibold)
      }
    }
    .task {
      configuration = appModel.preferences.speechConfiguration
      await refreshCredentialStatus()
    }
    .alert(
      "CourtVoice",
      isPresented: Binding(
        get: { operationMessage != nil },
        set: { if $0 == false { operationMessage = nil } }
      )
    ) {
      Button(l10n.ok, role: .cancel) { operationMessage = nil }
    } message: {
      Text(operationMessage ?? "")
    }
  }

  private func saveConfiguration() async {
    guard validateConfiguration() else { return }
    isSaving = true
    await appModel.updateSpeechConfiguration(configuration)
    isSaving = false
    dismiss()
  }

  private func saveOpenAIKey() async {
    do {
      try await appModel.credentialStore.save(openAIKey, for: .openAIAPIKey)
      openAIKey = ""
      await refreshCredentialStatus()
      operationMessage = l10n.openAIKeySaved
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func saveDeepSeekKey() async {
    do {
      try await appModel.credentialStore.save(deepseekKey, for: .deepseekAPIKey)
      deepseekKey = ""
      await refreshCredentialStatus()
      operationMessage = l10n.deepSeekKeySaved
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func saveDeepgramKey() async {
    do {
      try await appModel.credentialStore.save(deepgramKey, for: .deepgramAPIKey)
      deepgramKey = ""
      await refreshCredentialStatus()
      operationMessage = l10n.deepgramKeySaved
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func removeCredential(_ credential: ProviderCredential) async {
    do {
      try await appModel.credentialStore.remove(credential)
      await refreshCredentialStatus()
      operationMessage = l10n.credentialRemoved
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func refreshCredentialStatus() async {
    hasOpenAIKey = (try? await appModel.credentialStore.contains(.openAIAPIKey)) == true
    hasDeepgramKey = (try? await appModel.credentialStore.contains(.deepgramAPIKey)) == true
    hasDeepSeekKey = (try? await appModel.credentialStore.contains(.deepseekAPIKey)) == true
  }

  private func validateConfiguration() -> Bool {
    guard
      let endpoint = URL(string: configuration.openAITranscriptionEndpoint),
      endpoint.scheme?.lowercased() == "https"
    else {
      operationMessage = l10n.invalidOpenAIEndpoint
      return false
    }
    guard configuration.autoAcceptConfidence >= 0.75,
      configuration.autoAcceptConfidence <= 0.99
    else {
      operationMessage = l10n.invalidAcceptanceRange
      return false
    }
    if configuration.scoreReasoningEnabled {
      guard
        let reasoningEndpoint = URL(string: configuration.scoreReasoningEndpoint),
        reasoningEndpoint.scheme?.lowercased() == "https"
      else {
        operationMessage = l10n.invalidDeepSeekEndpoint
        return false
      }
    }
    return true
  }
}
