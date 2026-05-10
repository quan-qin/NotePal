import CommonCrypto
import CryptoKit
import Foundation
import Security

struct ThemeAssetEncryptionError: Error, CustomStringConvertible {
    let description: String
}

enum ThemeAssetEncryption {
    static let magic = Data("NPETASSET1".utf8)
    static let associatedData = Data("NotePet encrypted theme asset v1".utf8)
    static let saltByteCount = 16
    static let nonceByteCount = 12
    static let keyByteCount = 32
    static let keyDerivationRounds: UInt32 = 180_000

    static func normalizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func encrypt(_ data: Data, with rawKey: String) throws -> Data {
        let keyText = normalizedKey(rawKey)
        guard !keyText.isEmpty else {
            throw ThemeAssetEncryptionError(description: "Key must not be empty.")
        }

        let salt = try secureRandomData(byteCount: saltByteCount)
        let nonceData = try secureRandomData(byteCount: nonceByteCount)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let key = try deriveKey(from: keyText, salt: salt)
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce, authenticating: associatedData)

        var encrypted = Data()
        encrypted.append(magic)
        encrypted.append(salt)
        encrypted.append(nonceData)
        encrypted.append(sealedBox.ciphertext)
        encrypted.append(sealedBox.tag)
        return encrypted
    }

    private static func deriveKey(from keyText: String, salt: Data) throws -> SymmetricKey {
        let passwordData = Data(keyText.utf8)
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
            throw ThemeAssetEncryptionError(description: "Could not derive encryption key.")
        }

        return SymmetricKey(data: derivedKey)
    }

    private static func secureRandomData(byteCount: Int) throws -> Data {
        var data = Data(repeating: 0, count: byteCount)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.bindMemory(to: UInt8.self).baseAddress!)
        }

        guard status == errSecSuccess else {
            throw ThemeAssetEncryptionError(description: "Could not create secure random bytes.")
        }

        return data
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    throw ThemeAssetEncryptionError(
        description: "Usage: swift Scripts/encrypt_theme_asset.swift <input-png> <output-notepalasset> <key>"
    )
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let key = arguments[3]
let inputData = try Data(contentsOf: inputURL)
let encryptedData = try ThemeAssetEncryption.encrypt(inputData, with: key)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try encryptedData.write(to: outputURL, options: .atomic)

print("Wrote \(outputURL.path)")
