import Foundation
import SwiftUI

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
  case chinese = "zh-Hans"
  case english = "en"

  var id: String { rawValue }

  var locale: Locale {
    Locale(identifier: rawValue)
  }

  var speechLocaleIdentifier: String {
    switch self {
    case .chinese: "zh-CN"
    case .english: "en-US"
    }
  }

  var displayName: String {
    switch self {
    case .chinese: "简体中文"
    case .english: "English"
    }
  }
}

private struct L10nKey: EnvironmentKey {
  static let defaultValue = L10n(language: .chinese)
}

extension EnvironmentValues {
  var l10n: L10n {
    get { self[L10nKey.self] }
    set { self[L10nKey.self] = newValue }
  }
}
