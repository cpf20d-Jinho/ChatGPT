import Foundation
import CryptoKit

// Minimal single-block PBKDF2-HMAC-SHA256 (RFC 8018 §5.2), pure CryptoKit — no third-party
// dependency, works identically in the Xcode target and the Swift Playgrounds mirror.
// Single-block only: callers must request at most SHA256.byteCount (32) bytes of output.
enum PBKDF2 {
    static func deriveKey(password: String, salt: Data, iterations: Int, keyLength: Int) -> Data {
        precondition(keyLength <= SHA256.byteCount && keyLength > 0, "single-block PBKDF2 supports up to 32 bytes")
        precondition(iterations > 0)
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        func hmac(_ data: Data) -> Data {
            Data(HMAC<SHA256>.authenticationCode(for: data, using: passwordKey))
        }
        var block1Input = salt
        block1Input.append(contentsOf: [0, 0, 0, 1]) // INT_32_BE(block index 1)
        var previous = hmac(block1Input)
        var accumulated = previous
        for _ in 1..<iterations {
            previous = hmac(previous)
            for i in 0..<accumulated.count {
                accumulated[i] ^= previous[i]
            }
        }
        return accumulated.prefix(keyLength)
    }
}

// Derives the end-to-end profile-encryption key from the therapist's password. This key never
// leaves the device and is never sent to the server — only `profileKeySalt` is (it's not secret).
// Iteration count is tuned for on-device use (far faster hardware than the free-tier server, so
// this can afford to be much more expensive than the server's own login-hash cost).
enum TherapistProfileCrypto {
    static let pbkdf2Iterations = 300_000

    static func deriveProfileKey(password: String, profileKeySalt: Data) -> SymmetricKey {
        let raw = PBKDF2.deriveKey(password: password, salt: profileKeySalt, iterations: pbkdf2Iterations, keyLength: 32)
        return SymmetricKey(data: raw)
    }

    static func randomProfileKeySalt() -> Data {
        var bytes = Data(count: 16)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        precondition(status == errSecSuccess, "Failed to generate random salt")
        return bytes
    }

    // AES-256-GCM. `ciphertext` is stored as (ciphertext || tag); `nonce` is stored separately —
    // matching the server's `profile_ciphertext` / `profile_nonce` columns, which it never opens.
    static func encrypt(_ profile: TherapistProfile, key: SymmetricKey) throws -> (ciphertext: Data, nonce: Data) {
        let plaintext = try JSONEncoder().encode(profile)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        return (ciphertext: sealed.ciphertext + sealed.tag, nonce: Data(sealed.nonce))
    }

    static func decrypt(ciphertextAndTag: Data, nonce: Data, key: SymmetricKey) throws -> TherapistProfile {
        guard ciphertextAndTag.count > 16 else {
            throw NSError(domain: "TherapistAuth", code: 20, userInfo: [NSLocalizedDescriptionKey: "저장된 프로필 정보가 손상되었습니다."])
        }
        let tag = ciphertextAndTag.suffix(16)
        let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - 16)
        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(TherapistProfile.self, from: plaintext)
    }
}
