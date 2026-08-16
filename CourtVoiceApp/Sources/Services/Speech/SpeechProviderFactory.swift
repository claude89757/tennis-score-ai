import Foundation

@MainActor
struct SpeechProviderFactory {
  let configuration: SpeechConfiguration
  let credentialStore: ProviderCredentialStore

  func providerCandidates() async -> [SpeechProviderKind] {
    switch configuration.provider {
    case .automatic:
      var candidates: [SpeechProviderKind] = [.appleOnDevice]
      if (try? await credentialStore.contains(.openAIAPIKey)) == true {
        candidates.append(.openAICompatible)
      }
      if (try? await credentialStore.contains(.deepgramAPIKey)) == true {
        candidates.append(.deepgram)
      }
      return candidates
    case let provider:
      return [provider]
    }
  }

  func makeProvider(_ kind: SpeechProviderKind) async throws -> any LiveSpeechProvider {
    switch kind {
    case .automatic:
      throw SpeechProviderError.providerUnavailable("Automatic is a routing mode, not a provider.")
    case .appleOnDevice:
      return AppleSpeechProvider()
    case .openAICompatible:
      guard let key = try await credentialStore.value(for: .openAIAPIKey) else {
        throw SpeechProviderError.missingCredential("OpenAI-compatible")
      }
      guard let endpoint = URL(string: configuration.openAITranscriptionEndpoint) else {
        throw SpeechProviderError.invalidEndpoint
      }
      return OpenAICompatibleSpeechProvider(
        apiKey: key,
        endpoint: endpoint,
        model: configuration.openAITranscriptionModel
      )
    case .deepgram:
      guard let key = try await credentialStore.value(for: .deepgramAPIKey) else {
        throw SpeechProviderError.missingCredential("Deepgram")
      }
      return DeepgramSpeechProvider(
        apiKey: key,
        model: configuration.deepgramModel,
        language: configuration.deepgramLanguage
      )
    }
  }
}
