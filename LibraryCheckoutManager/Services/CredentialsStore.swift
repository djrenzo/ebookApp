import Foundation
import Security

/// Keychain-backed storage for the signed-in patron session. Returns `nil`
/// until `save(_:)` is called after a successful `LibraryAuthService.login()`
/// — there's no seeded fallback anymore, since real credentials come from a
/// real login instead of a hardcoded session.
actor CredentialsStore {
    static let shared = CredentialsStore()

    private let service = "com.superapp.librarycheckoutmanager.credentials"

    private enum Key: String, CaseIterable {
        case patronId, appToken, appTokenExpiresAt, patronToken, patronTokenExpiresAt
        case patronRefreshToken, displayName, email
    }

    func load() -> LibraryCredentials? {
        guard let patronId = readString(.patronId),
              let appToken = readString(.appToken),
              let appTokenExpiresAt = readDate(.appTokenExpiresAt),
              let patronToken = readString(.patronToken),
              let patronTokenExpiresAt = readDate(.patronTokenExpiresAt),
              let patronRefreshToken = readString(.patronRefreshToken) else {
            return nil
        }
        return LibraryCredentials(
            patronId: patronId,
            appToken: appToken,
            appTokenExpiresAt: appTokenExpiresAt,
            patronToken: patronToken,
            patronTokenExpiresAt: patronTokenExpiresAt,
            patronRefreshToken: patronRefreshToken,
            displayName: readString(.displayName) ?? "",
            email: readString(.email) ?? ""
        )
    }

    func save(_ credentials: LibraryCredentials) {
        write(.patronId, credentials.patronId)
        write(.appToken, credentials.appToken)
        write(.appTokenExpiresAt, Self.dateFormatter.string(from: credentials.appTokenExpiresAt))
        write(.patronToken, credentials.patronToken)
        write(.patronTokenExpiresAt, Self.dateFormatter.string(from: credentials.patronTokenExpiresAt))
        write(.patronRefreshToken, credentials.patronRefreshToken)
        write(.displayName, credentials.displayName)
        write(.email, credentials.email)
    }

    /// Updates just the app token after a silent refresh, leaving the
    /// patron token untouched.
    func updateAppToken(_ appToken: String, expiresAt: Date) {
        write(.appToken, appToken)
        write(.appTokenExpiresAt, Self.dateFormatter.string(from: expiresAt))
    }

    func clear() {
        for key in Key.allCases {
            delete(key)
        }
    }

    private static let dateFormatter = ISO8601DateFormatter()

    private func readDate(_ key: Key) -> Date? {
        readString(key).flatMap(Self.dateFormatter.date(from:))
    }

    private func readString(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ key: Key, _ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
        var addQuery = identity
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        switch SecItemAdd(addQuery as CFDictionary, nil) {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let status = SecItemUpdate(identity as CFDictionary, [kSecValueData: data] as CFDictionary)
            if status != errSecSuccess {
                NSLog("CredentialsStore: failed to update \(key.rawValue), status=\(status)")
            }
        case let status:
            NSLog("CredentialsStore: failed to add \(key.rawValue), status=\(status)")
        }
    }

    private func delete(_ key: Key) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
