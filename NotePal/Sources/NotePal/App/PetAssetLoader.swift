import AppKit
import Foundation

@MainActor
enum PetAssetLoader {
    private static var publicImages: [PetTheme: NSImage] = {
        var loadedImages: [PetTheme: NSImage] = [:]

        for theme in PetTheme.allCases where !theme.isSpecial {
            guard
                let resourceName = theme.publicResourceName,
                let url = AppResourceBundle.url(forResource: resourceName, withExtension: "png"),
                let image = NSImage(contentsOf: url),
                image.isValid
            else {
                continue
            }

            loadedImages[theme] = image
        }

        return loadedImages
    }()

    private static var decryptedImages: [PetTheme: NSImage] = [:]

    static func image(for theme: PetTheme) -> NSImage? {
        guard theme.isSpecial else {
            return publicImages[theme]
        }

        if let image = decryptedImages[theme] {
            return image
        }

        guard let savedKey = PetThemeCredentialStore.savedKey(for: theme),
              let image = decryptImage(for: theme, key: savedKey)
        else {
            return nil
        }

        decryptedImages[theme] = image
        return image
    }

    static func unlockSpecialTheme(with key: String) throws -> PetTheme? {
        let normalizedKey = EncryptedThemeAsset.normalizedKey(key)
        guard !normalizedKey.isEmpty else {
            return nil
        }

        for theme in PetTheme.allCases where theme.isSpecial {
            guard let image = decryptImage(for: theme, key: normalizedKey) else {
                continue
            }

            try PetThemeCredentialStore.saveKey(normalizedKey, for: theme)
            decryptedImages[theme] = image
            return theme
        }

        return nil
    }

    private static func decryptImage(for theme: PetTheme, key: String) -> NSImage? {
        guard
            let encryptedData = encryptedData(for: theme),
            let imageData = try? EncryptedThemeAsset.decrypt(encryptedData, with: key),
            let image = NSImage(data: imageData),
            image.isValid
        else {
            return nil
        }

        return image
    }

    private static func encryptedData(for theme: PetTheme) -> Data? {
        guard
            let resourceName = theme.encryptedResourceName,
            let url = AppResourceBundle.url(
                forResource: resourceName,
                withExtension: EncryptedThemeAsset.fileExtension
            )
        else {
            return nil
        }

        return try? Data(contentsOf: url)
    }
}
