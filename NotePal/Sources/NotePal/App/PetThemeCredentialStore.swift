import Foundation

enum PetThemeCredentialStore {
    private static let keyPrefix = "themeKey."

    static func savedKey(for theme: PetTheme) -> String? {
        guard theme.isSpecial else {
            return nil
        }

        for accountID in theme.storedIDs {
            if let key = UserDefaults.standard.string(forKey: storageKey(accountID: accountID)),
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

        for accountID in theme.storedIDs {
            UserDefaults.standard.set(key, forKey: storageKey(accountID: accountID))
        }
    }

    static func deleteKey(for theme: PetTheme) {
        for accountID in theme.storedIDs {
            UserDefaults.standard.removeObject(forKey: storageKey(accountID: accountID))
        }
    }

    private static func storageKey(accountID: String) -> String {
        "\(keyPrefix)\(accountID)"
    }
}

enum PetThemeCredentialError: Error {
    case emptyKey
}
