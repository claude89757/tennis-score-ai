import CourtVoiceCore
import Foundation

actor MatchRepository {
  enum RepositoryError: LocalizedError {
    case couldNotCreateDirectory

    var errorDescription: String? {
      switch self {
      case .couldNotCreateDirectory:
        return "CourtVoice could not create its local data directory."
      }
    }
  }

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(baseDirectory: URL? = nil) {
    let directory = baseDirectory ?? Self.defaultDirectory()
    fileURL = directory.appendingPathComponent("matches.json", isDirectory: false)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  func loadAll() throws -> [SavedMatch] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    let data = try Data(contentsOf: fileURL)
    return try decoder.decode([SavedMatch].self, from: data)
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  func save(_ timeline: MatchTimeline) throws {
    var matches = try loadAll()
    let saved = SavedMatch(timeline: timeline)

    if let index = matches.firstIndex(where: { $0.id == saved.id }) {
      matches[index] = saved
    } else {
      matches.append(saved)
    }

    try write(matches.sorted { $0.updatedAt > $1.updatedAt })
  }

  func delete(id: UUID) throws {
    let matches = try loadAll().filter { $0.id != id }
    try write(matches)
  }

  func deleteAll() throws {
    try write([])
  }

  private func write(_ matches: [SavedMatch]) throws {
    let directory = fileURL.deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: directory.path) == false {
      do {
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
      } catch {
        throw RepositoryError.couldNotCreateDirectory
      }
    }

    let data = try encoder.encode(matches)
    try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
  }

  private static func defaultDirectory() -> URL {
    let root =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    return root.appendingPathComponent("CourtVoice", isDirectory: true)
  }
}

actor PreferencesRepository {
  private let fileURL: URL

  init(baseDirectory: URL? = nil) {
    let root =
      baseDirectory ?? FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    fileURL =
      root
      .appendingPathComponent("CourtVoice", isDirectory: true)
      .appendingPathComponent("preferences.json", isDirectory: false)
  }

  func load() throws -> AppPreferences {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return .initial
    }
    return try JSONDecoder().decode(
      AppPreferences.self,
      from: Data(contentsOf: fileURL)
    )
  }

  func save(_ preferences: AppPreferences) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(preferences)
    try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
  }
}
