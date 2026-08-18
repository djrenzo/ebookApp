import Foundation
import Security

/// Keychain-backed storage for the connected Hardcover account. Returns
/// `nil` until a token has been validated and saved via Settings — no
/// seeded fallback, same as `CredentialsStore`.
actor HardcoverCredentialsStore {
    static let shared = HardcoverCredentialsStore()

    private let service = "com.superapp.librarycheckoutmanager.hardcover"

    private enum Key: String, CaseIterable {
        case token, userId, username
    }

    func load() -> HardcoverCredentials? {
        guard let token = readString(.token),
              let userIdString = readString(.userId),
              let userId = Int(userIdString),
              let username = readString(.username) else {
            return nil
        }
        return HardcoverCredentials(token: token, userId: userId, username: username)
    }

    func save(_ credentials: HardcoverCredentials) {
        write(.token, credentials.token)
        write(.userId, String(credentials.userId))
        write(.username, credentials.username)
    }

    func clear() {
        for key in Key.allCases {
            delete(key)
        }
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
                NSLog("HardcoverCredentialsStore: failed to update \(key.rawValue), status=\(status)")
            }
        case let status:
            NSLog("HardcoverCredentialsStore: failed to add \(key.rawValue), status=\(status)")
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
