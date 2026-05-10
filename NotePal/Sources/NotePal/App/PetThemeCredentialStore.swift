import Foundation
import Security

enum PetThemeCredentialStore {
    private static let service = "app.notepal.theme-key"

    static func savedKey(for theme: PetTheme) -> String? {
        guard theme.isSpecial else {
            return nil
        }

        for accountID in theme.storedIDs {
            var query = baseQuery(accountID: accountID)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecSuccess,
               let data = item as? Data,
               let key = String(data: data, encoding: .utf8),
               !key.isEmpty {
                return key
            }
        }

        return nil
    }

    static func hasSavedKey(for theme: PetTheme) -> Bool {
        savedKey(for: theme) != nil
    }

    static func saveKey(_ rawKey: String, for theme: PetTheme) throws {
        guard theme.isSpecial else {
            return
        }

        let key = EncryptedThemeAsset.normalizedKey(rawKey)
        guard !key.isEmpty else {
            throw PetThemeCredentialError.emptyKey
        }

        let keyData = Data(key.utf8)
        var query = baseQuery(accountID: theme.rawValue)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = keyData
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PetThemeCredentialError.keychainFailure(status)
        }
    }

    static func deleteKey(for theme: PetTheme) {
        for accountID in theme.storedIDs {
            SecItemDelete(baseQuery(accountID: accountID) as CFDictionary)
        }
    }

    private static func baseQuery(accountID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID
        ]
    }
}

enum PetThemeCredentialError: Error {
    case emptyKey
    case keychainFailure(OSStatus)
}
