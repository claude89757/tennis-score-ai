import CourtVoiceCore
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  enum Tab: Hashable {
    case home
    case history
    case settings
  }

  let matchRepository: MatchRepository
  let preferencesRepository: PreferencesRepository
  let credentialStore: ProviderCredentialStore

  var selectedTab: Tab = .home
  var matches: [SavedMatch] = []
  var activeSession: MatchSessionController?
  var isBootstrapping = true
  var preferences: AppPreferences = .initial
  var errorMessage: String?

  var hasCompletedOnboarding: Bool {
    preferences.hasCompletedOnboarding
  }

  init(
    matchRepository: MatchRepository = MatchRepository(),
    preferencesRepository: PreferencesRepository = PreferencesRepository(),
    credentialStore: ProviderCredentialStore = ProviderCredentialStore()
  ) {
    self.matchRepository = matchRepository
    self.preferencesRepository = preferencesRepository
    self.credentialStore = credentialStore
  }

  func bootstrap() async {
    guard isBootstrapping else { return }

    do {
      async let storedMatches = matchRepository.loadAll()
      async let storedPreferences = preferencesRepository.load()
      let loadedMatches = try await storedMatches
      let loadedPreferences = try await storedPreferences
      matches = loadedMatches
      preferences = loadedPreferences
    } catch {
      errorMessage = error.localizedDescription
    }

    isBootstrapping = false
  }

  func completeOnboarding() async {
    preferences.hasCompletedOnboarding = true
    await savePreferences()
  }

  func updateSpeechConfiguration(_ configuration: SpeechConfiguration) async {
    preferences.speechConfiguration = configuration
    await savePreferences()
  }

  func startMatch(from draft: MatchConfigurationDraft) async {
    do {
      let controller = try MatchSessionController(
        initialState: draft.makeInitialState(),
        repository: matchRepository,
        speechConfiguration: preferences.speechConfiguration,
        credentialStore: credentialStore
      )
      activeSession = controller
      try await controller.persist()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func resume(_ savedMatch: SavedMatch) {
    activeSession = MatchSessionController(
      savedMatch: savedMatch,
      repository: matchRepository,
      speechConfiguration: preferences.speechConfiguration,
      credentialStore: credentialStore
    )
  }

  func closeActiveMatch() async {
    if let activeSession {
      await activeSession.stopListening()
      do {
        try await activeSession.persist()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
    activeSession = nil
    await refreshMatches()
  }

  func refreshMatches() async {
    do {
      matches = try await matchRepository.loadAll()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteMatches(at offsets: IndexSet) async {
    let identifiers = offsets.compactMap { index in
      matches.indices.contains(index) ? matches[index].id : nil
    }

    do {
      for identifier in identifiers {
        try await matchRepository.delete(id: identifier)
      }
      await refreshMatches()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func savePreferences() async {
    do {
      try await preferencesRepository.save(preferences)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
