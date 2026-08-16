import Foundation
import SwiftUI

struct ModelSettingsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss

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
      Section("Voice mode") {
        Picker("Provider", selection: $configuration.provider) {
          ForEach(SpeechProviderKind.allCases) { provider in
            VStack(alignment: .leading) {
              Text(provider.title)
              Text(provider.subtitle)
            }
            .tag(provider)
          }
        }

        Picker("Recognition language", selection: $configuration.localeIdentifier) {
          Text("简体中文").tag("zh-CN")
          Text("English (US)").tag("en-US")
          Text("한국어").tag("ko-KR")
        }

        VStack(alignment: .leading, spacing: 8) {
          LabeledContent(
            "Automatic acceptance",
            value: configuration.autoAcceptConfidence.formatted(
              .percent.precision(.fractionLength(0)))
          )
          Slider(value: $configuration.autoAcceptConfidence, in: 0.75...0.99, step: 0.01)
          Text(
            "Calls below this confidence do not change the official score. A short pause after a stable call commits it for scoring and model thinking, even if the recognizer has not marked the transcript final."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }

      Section {
        TextField("HTTPS transcription endpoint", text: $configuration.openAITranscriptionEndpoint)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        TextField("Transcription model", text: $configuration.openAITranscriptionModel)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasOpenAIKey ? "API key saved — enter to replace" : "API key",
          text: $openAIKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button("Save key") {
            Task { await saveOpenAIKey() }
          }
          .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasOpenAIKey {
            Spacer()
            Button("Remove", role: .destructive) {
              Task { await removeCredential(.openAIAPIKey) }
            }
          }
        }
      } header: {
        Text("OpenAI-compatible BYOK")
      } footer: {
        Text(
          "Short voice segments are sent directly from this device to the configured endpoint. The provider may bill your own account. CourtVoice never adds the key to logs or match exports."
        )
      }

      Section {
        TextField("Model", text: $configuration.deepgramModel)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        TextField("Language code or multi", text: $configuration.deepgramLanguage)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasDeepgramKey ? "API key saved — enter to replace" : "API key",
          text: $deepgramKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button("Save key") {
            Task { await saveDeepgramKey() }
          }
          .disabled(deepgramKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasDeepgramKey {
            Spacer()
            Button("Remove", role: .destructive) {
              Task { await removeCredential(.deepgramAPIKey) }
            }
          }
        }
      } header: {
        Text("Deepgram BYOK")
      } footer: {
        Text(
          "While the voice agent is listening, 16 kHz mono PCM is streamed directly to Deepgram. Stopping the agent or closing the match stops capture."
        )
      }

      Section {
        Toggle("Stream thinking on the live board", isOn: $configuration.scoreReasoningEnabled)

        Picker("Model", selection: $configuration.scoreReasoningModel) {
          Text("deepseek-v4-flash").tag("deepseek-v4-flash")
          Text("deepseek-v4-pro").tag("deepseek-v4-pro")
        }

        TextField("HTTPS chat endpoint", text: $configuration.scoreReasoningEndpoint)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        SecureField(
          hasDeepSeekKey ? "API key saved — enter to replace" : "API key",
          text: $deepseekKey
        )
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .privacySensitive()

        HStack {
          Button("Save key") {
            Task { await saveDeepSeekKey() }
          }
          .disabled(deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if hasDeepSeekKey {
            Spacer()
            Button("Remove", role: .destructive) {
              Task { await removeCredential(.deepseekAPIKey) }
            }
          }
        }
      } header: {
        Text("DeepSeek score reasoning")
      } footer: {
        Text(
          "DeepSeek is the live thinking model, not the transcriber. It streams reasoning on the match screen and may propose a structured intent. Only the tennis rules engine can change the official score. The key stays in this device's Keychain."
        )
      }

      Section {
        Label(
          "Raw microphone audio is not stored by the live scoring workflow.",
          systemImage: "lock.shield.fill"
        )
        .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Speech & AI")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(isSaving ? "Saving…" : "Save") {
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
      Button("OK", role: .cancel) { operationMessage = nil }
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
      operationMessage = "OpenAI-compatible key saved in the device-only Keychain."
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func saveDeepSeekKey() async {
    do {
      try await appModel.credentialStore.save(deepseekKey, for: .deepseekAPIKey)
      deepseekKey = ""
      await refreshCredentialStatus()
      operationMessage = "DeepSeek key saved in the device-only Keychain."
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func saveDeepgramKey() async {
    do {
      try await appModel.credentialStore.save(deepgramKey, for: .deepgramAPIKey)
      deepgramKey = ""
      await refreshCredentialStatus()
      operationMessage = "Deepgram key saved in the device-only Keychain."
    } catch {
      operationMessage = error.localizedDescription
    }
  }

  private func removeCredential(_ credential: ProviderCredential) async {
    do {
      try await appModel.credentialStore.remove(credential)
      await refreshCredentialStatus()
      operationMessage = "Credential removed."
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
      operationMessage = "The OpenAI-compatible transcription endpoint must be a valid HTTPS URL."
      return false
    }
    guard configuration.autoAcceptConfidence >= 0.75,
      configuration.autoAcceptConfidence <= 0.99
    else {
      operationMessage = "The automatic-acceptance threshold is outside the supported range."
      return false
    }
    if configuration.scoreReasoningEnabled {
      guard
        let reasoningEndpoint = URL(string: configuration.scoreReasoningEndpoint),
        reasoningEndpoint.scheme?.lowercased() == "https"
      else {
        operationMessage = "The DeepSeek endpoint must be a valid HTTPS URL."
        return false
      }
    }
    return true
  }
}
