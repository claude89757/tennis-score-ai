import Foundation
import Security

enum ProviderCredential: String, Sendable {
  case openAIAPIKey = "provider.openai.api-key"
  case deepgramAPIKey = "provider.deepgram.api-key"
}

actor ProviderCredentialStore {
  enum CredentialError: LocalizedError {
    case invalidValue
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
      switch self {
      case .invalidValue:
        "The credential is empty or cannot be encoded."
      case .unexpectedStatus(let status):
        "Keychain operation failed with status \(status)."
      }
    }
  }

  private let service: String

  init(service: String = "com.claude89757.courtvoice.providers") {
    self.service = service
  }

  func save(_ value: String, for credential: ProviderCredential) throws {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.isEmpty == false, let data = normalized.data(using: .utf8) else {
      throw CredentialError.invalidValue
    }

    let query = baseQuery(for: credential)
    SecItemDelete(query as CFDictionary)

    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw CredentialError.unexpectedStatus(status)
    }
  }

  func value(for credential: ProviderCredential) throws -> String? {
    var query = baseQuery(for: credential)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else {
      throw CredentialError.unexpectedStatus(status)
    }
    guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
      throw CredentialError.invalidValue
    }
    return value
  }

  func contains(_ credential: ProviderCredential) throws -> Bool {
    try value(for: credential) != nil
  }

  func remove(_ credential: ProviderCredential) throws {
    let status = SecItemDelete(baseQuery(for: credential) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CredentialError.unexpectedStatus(status)
    }
  }

  private func baseQuery(for credential: ProviderCredential) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: credential.rawValue,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
    ]
  }
}
