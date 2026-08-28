import Foundation
import Security

/// Keychain-backed storage for the Resend "Send to Kindle" configuration.
/// Returns `nil` until the user saves it from Settings — no seeded
/// fallback, same as `CredentialsStore`/`HardcoverCredentialsStore`.
actor ResendCredentialsStore {
    static let shared = ResendCredentialsStore()

    private let service = "com.superapp.librarycheckoutmanager.resend"

    private enum Key: String, CaseIterable {
        case apiKey, fromEmail, kindleEmail
    }

    func load() -> ResendCredentials? {
        guard let apiKey = readString(.apiKey),
              let fromEmail = readString(.fromEmail),
              let kindleEmail = readString(.kindleEmail) else {
            return nil
        }
        return ResendCredentials(apiKey: apiKey, fromEmail: fromEmail, kindleEmail: kindleEmail)
    }

    func save(_ credentials: ResendCredentials) {
        write(.apiKey, credentials.apiKey)
        write(.fromEmail, credentials.fromEmail)
        write(.kindleEmail, credentials.kindleEmail)
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
                NSLog("ResendCredentialsStore: failed to update \(key.rawValue), status=\(status)")
            }
        case let status:
            NSLog("ResendCredentialsStore: failed to add \(key.rawValue), status=\(status)")
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
