import CommonCrypto
import CryptoKit
import Foundation

/// Manager for encrypting and decrypting sensitive data using AES-256-GCM
final class EncryptionManager {
    enum EncryptionError: LocalizedError {
        case invalidPassword
        case encryptionFailed
        case decryptionFailed
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidPassword:
                return "Invalid encryption password"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data - password may be incorrect"
            case .invalidFormat:
                return "Invalid encrypted data format"
            }
        }
    }

    private let storage: SecureStorage

    init(storage: SecureStorage = SecureStorage()) {
        self.storage = storage
    }

    // MARK: - Password-Based Encryption

    /// Encrypts data using a password-derived key (PBKDF2 + AES-256-GCM)
    func encrypt(_ data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        // Generate random salt
        var salt = Data(count: 16)
        let saltStatus = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard saltStatus == errSecSuccess else {
            throw EncryptionError.encryptionFailed
        }

        // Derive key from password using PBKDF2
        let key = try deriveKey(from: password, salt: salt)

        // Generate random nonce
        let nonce = AES.GCM.Nonce()

        // Encrypt data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        // Format: [salt (16 bytes)][encrypted data with nonce and tag]
        var result = Data()
        result.append(salt)
        result.append(combined)

        return result
    }

    /// Decrypts data that was encrypted with password
    func decrypt(_ data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw EncryptionError.invalidPassword
        }

        guard data.count > 16 else {
            throw EncryptionError.invalidFormat
        }

        // Extract salt
        let salt = data.prefix(16)
        let encryptedData = data.dropFirst(16)

        // Derive key from password
        let key = try deriveKey(from: password, salt: salt)

        // Decrypt
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    // MARK: - Symmetric Key Encryption

    /// Encrypts data using a stored symmetric key (for app-level encryption)
    func encryptWithAppKey(_ data: Data) throws -> Data {
        let key = try getOrCreateAppKey()
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }

    /// Decrypts data using the stored symmetric key
    func decryptWithAppKey(_ data: Data) throws -> Data {
        let key = try getOrCreateAppKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - File Encryption

    /// Encrypts a file and writes to destination path
    func encryptFile(at sourcePath: URL, to destinationPath: URL, password: String) throws {
        let data = try Data(contentsOf: sourcePath)
        let encryptedData = try encrypt(data, password: password)
        try encryptedData.write(to: destinationPath, options: .atomic)
    }

    /// Decrypts a file and writes to destination path
    func decryptFile(at sourcePath: URL, to destinationPath: URL, password: String) throws {
        let encryptedData = try Data(contentsOf: sourcePath)
        let decryptedData = try decrypt(encryptedData, password: password)
        try decryptedData.write(to: destinationPath, options: .atomic)
    }

    // MARK: - Private Helpers

    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPassword
        }

        // Use PBKDF2 to derive a key from the password
        // 100,000 iterations for strong key derivation
        let derivedKey = try deriveKeyPBKDF2(
            password: passwordData,
            salt: salt,
            iterations: 100_000,
            keyLength: 32  // 256 bits for AES-256
        )

        return SymmetricKey(data: derivedKey)
    }

    private func deriveKeyPBKDF2(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        var derivedKeyData = Data(count: keyLength)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            throw EncryptionError.encryptionFailed
        }

        return derivedKeyData
    }

    private func getOrCreateAppKey() throws -> SymmetricKey {
        let keyIdentifier = "app.encryption.key"

        // Try to load existing key
        if let existingKeyData: Data = try storage.load(forKey: keyIdentifier) {
            return SymmetricKey(data: existingKeyData)
        }

        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try storage.save(keyData, forKey: keyIdentifier)

        return newKey
    }
}
