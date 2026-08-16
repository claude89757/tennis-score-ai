import Foundation
import SwiftUI

struct ModelSettingsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss

  @State private var configuration = SpeechConfiguration.standard
  @State private var openAIKey = ""
  @State private var deepgramKey = ""
  @State private var hasOpenAIKey = false
  @State private var hasDeepgramKey = false
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
            "Lower-confidence or non-linear score changes are held for confirmation instead of changing the scoreboard."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }

      Section("OpenAI-compatible BYOK") {
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
      } footer: {
        Text(
          "Short voice segments are sent directly from this device to the configured endpoint. The provider may bill your own account. CourtVoice never adds the key to logs or match exports."
        )
      }

      Section("Deepgram BYOK") {
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
      } footer: {
        Text(
          "While listening is active, 16 kHz mono PCM is streamed directly to Deepgram. Stopping or pausing the match stops capture."
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
    return true
  }
}
