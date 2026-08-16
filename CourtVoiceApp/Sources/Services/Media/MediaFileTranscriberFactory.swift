import Foundation

@MainActor
struct MediaFileTranscriberFactory {
  let configuration: SpeechConfiguration
  let credentialStore: ProviderCredentialStore

  func makeTranscriber() async throws -> any MediaFileTranscriber {
    switch configuration.provider {
    case .appleOnDevice:
      return AppleMediaFileTranscriber()
    case .openAICompatible:
      return try await makeOpenAI()
    case .deepgram:
      return try await makeDeepgram()
    case .automatic:
      if (try? await credentialStore.contains(.openAIAPIKey)) == true {
        return try await makeOpenAI()
      }
      if (try? await credentialStore.contains(.deepgramAPIKey)) == true {
        return try await makeDeepgram()
      }
      return AppleMediaFileTranscriber()
    }
  }

  private func makeOpenAI() async throws -> any MediaFileTranscriber {
    guard let key = try await credentialStore.value(for: .openAIAPIKey) else {
      throw SpeechProviderError.missingCredential("OpenAI-compatible")
    }
    guard let endpoint = URL(string: configuration.openAITranscriptionEndpoint) else {
      throw SpeechProviderError.invalidEndpoint
    }
    return OpenAIMediaFileTranscriber(
      apiKey: key,
      endpoint: endpoint,
      model: configuration.openAITranscriptionModel
    )
  }

  private func makeDeepgram() async throws -> any MediaFileTranscriber {
    guard let key = try await credentialStore.value(for: .deepgramAPIKey) else {
      throw SpeechProviderError.missingCredential("Deepgram")
    }
    return DeepgramMediaFileTranscriber(
      apiKey: key,
      model: configuration.deepgramModel,
      language: configuration.deepgramLanguage
    )
  }
}
