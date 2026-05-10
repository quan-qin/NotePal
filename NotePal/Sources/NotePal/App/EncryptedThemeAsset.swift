import CommonCrypto
import CryptoKit
import Foundation

enum EncryptedThemeAsset {
    static let fileExtension = "notepalasset"

    private static let magic = Data("NPETASSET1".utf8)
    // Keep the original associated data so existing encrypted theme assets remain readable.
    private static let associatedData = Data("NotePet encrypted theme asset v1".utf8)
    private static let saltByteCount = 16
    private static let nonceByteCount = 12
    private static let tagByteCount = 16
    private static let keyByteCount = 32
    private static let keyDerivationRounds: UInt32 = 180_000

    static func normalizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func decrypt(_ encryptedData: Data, with rawKey: String) throws -> Data {
        let keyText = normalizedKey(rawKey)
        guard !keyText.isEmpty else {
            throw EncryptedThemeAssetError.emptyKey
        }

        let minimumByteCount = magic.count + saltByteCount + nonceByteCount + tagByteCount + 1
        guard encryptedData.count >= minimumByteCount,
              encryptedData.prefix(magic.count) == magic
        else {
            throw EncryptedThemeAssetError.invalidAsset
        }

        var offset = magic.count
        let salt = encryptedData.subdata(in: offset..<(offset + saltByteCount))
        offset += saltByteCount
        let nonceData = encryptedData.subdata(in: offset..<(offset + nonceByteCount))
        offset += nonceByteCount

        let sealedData = encryptedData.subdata(in: offset..<encryptedData.count)
        guard sealedData.count > tagByteCount else {
            throw EncryptedThemeAssetError.invalidAsset
        }

        let ciphertext = sealedData.prefix(sealedData.count - tagByteCount)
        let tag = sealedData.suffix(tagByteCount)
        let symmetricKey = try deriveKey(from: keyText, salt: salt)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: Data(ciphertext),
            tag: Data(tag)
        )

        return try AES.GCM.open(sealedBox, using: symmetricKey, authenticating: associatedData)
    }

    private static func deriveKey(from keyText: String, salt: Data) throws -> SymmetricKey {
        let passwordData = Data(keyText.utf8)
        guard !passwordData.isEmpty else {
            throw EncryptedThemeAssetError.emptyKey
        }

        var derivedKey = Data(repeating: 0, count: keyByteCount)
        let status = passwordData.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                derivedKey.withUnsafeMutableBytes { derivedBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        keyDerivationRounds,
                        derivedBuffer.bindMemory(to: UInt8.self).baseAddress,
                        keyByteCount
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw EncryptedThemeAssetError.keyDerivationFailed
        }

        return SymmetricKey(data: derivedKey)
    }
}

enum EncryptedThemeAssetError: Error {
    case emptyKey
    case invalidAsset
    case keyDerivationFailed
}
