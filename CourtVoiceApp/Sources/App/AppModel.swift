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

  var selectedTab: Tab = .home
  var matches: [SavedMatch] = []
  var activeSession: MatchSessionController?
  var isBootstrapping = true
  var hasCompletedOnboarding = false
  var errorMessage: String?

  init(
    matchRepository: MatchRepository = MatchRepository(),
    preferencesRepository: PreferencesRepository = PreferencesRepository()
  ) {
    self.matchRepository = matchRepository
    self.preferencesRepository = preferencesRepository
  }

  func bootstrap() async {
    guard isBootstrapping else { return }

    do {
      async let storedMatches = matchRepository.loadAll()
      async let preferences = preferencesRepository.load()
      let loadedMatches = try await storedMatches
      let loadedPreferences = try await preferences
      matches = loadedMatches
      hasCompletedOnboarding = loadedPreferences.hasCompletedOnboarding
    } catch {
      errorMessage = error.localizedDescription
    }

    isBootstrapping = false
  }

  func completeOnboarding() async {
    hasCompletedOnboarding = true
    do {
      try await preferencesRepository.save(
        AppPreferences(hasCompletedOnboarding: true)
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func startMatch(from draft: MatchConfigurationDraft) async {
    do {
      let controller = try MatchSessionController(
        initialState: draft.makeInitialState(),
        repository: matchRepository
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
      repository: matchRepository
    )
  }

  func closeActiveMatch() async {
    if let activeSession {
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
}
