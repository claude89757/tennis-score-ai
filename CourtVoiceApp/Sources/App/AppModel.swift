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
  let entitlementStore: EntitlementStore

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
    credentialStore: ProviderCredentialStore = ProviderCredentialStore(),
    entitlementStore: EntitlementStore = EntitlementStore()
  ) {
    self.matchRepository = matchRepository
    self.preferencesRepository = preferencesRepository
    self.credentialStore = credentialStore
    self.entitlementStore = entitlementStore
  }

  func prepareLaunchConfiguration() async {
    let arguments = ProcessInfo.processInfo.arguments
    guard arguments.contains("-ui-testing") else { return }

    do {
      if arguments.contains("-ui-testing-reset") {
        try await matchRepository.deleteAll()
        var next = AppPreferences.initial
        if arguments.contains("-ui-testing-skip-onboarding") {
          next.hasCompletedOnboarding = true
        }
        try await preferencesRepository.save(next)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func bootstrap() async {
    guard isBootstrapping else { return }
    await seedDebugProviderKeys()

    async let entitlementStart: Void = entitlementStore.start()
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

    _ = await entitlementStart
    isBootstrapping = false
  }

  func completeOnboarding() async {
    preferences.hasCompletedOnboarding = true
    await savePreferences()
  }

  var l10n: L10n {
    L10n(language: preferences.appLanguage)
  }

  func updateSpeechConfiguration(_ configuration: SpeechConfiguration) async {
    preferences.speechConfiguration = configuration
    await savePreferences()
  }

  func updateAppLanguage(_ language: AppLanguage) async {
    preferences.appLanguage = language
    preferences.speechConfiguration.localeIdentifier = language.speechLocaleIdentifier
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

  private func seedDebugProviderKeys() async {
    #if DEBUG
      guard
        let key = ProcessInfo.processInfo.environment["COURTVOICE_DEEPSEEK_API_KEY"],
        key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      else {
        return
      }
      try? await credentialStore.save(key, for: .deepseekAPIKey)
    #endif
  }

  private func savePreferences() async {
    do {
      try await preferencesRepository.save(preferences)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
