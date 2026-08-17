import Foundation
import Security

/// Keychain-backed storage for the Odilo session credentials. Seeds itself
/// with `LibraryCredentials.seeded` until the user saves an edit in Settings.
actor CredentialsStore {
    static let shared = CredentialsStore()

    private let service = "com.superapp.librarycheckoutmanager.credentials"

    private enum Key: String, CaseIterable {
        case patronId, bearerToken, jsessionId, awsalb, awsalbcors
    }

    func load() -> LibraryCredentials {
        let seeded = LibraryCredentials.seeded
        return LibraryCredentials(
            patronId: readString(.patronId) ?? seeded.patronId,
            bearerToken: readString(.bearerToken) ?? seeded.bearerToken,
            jsessionId: readString(.jsessionId) ?? seeded.jsessionId,
            awsalb: readString(.awsalb) ?? seeded.awsalb,
            awsalbcors: readString(.awsalbcors) ?? seeded.awsalbcors
        )
    }

    func save(_ credentials: LibraryCredentials) {
        write(.patronId, credentials.patronId)
        write(.bearerToken, credentials.bearerToken)
        write(.jsessionId, credentials.jsessionId)
        write(.awsalb, credentials.awsalb)
        write(.awsalbcors, credentials.awsalbcors)
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
}
