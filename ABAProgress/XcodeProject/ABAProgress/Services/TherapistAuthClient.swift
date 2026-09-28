import Foundation
import CryptoKit
import Security

// Decrypted, in-memory representation of a logged-in therapist session.
struct TherapistSession {
    let profile: TherapistProfile
}

// Talks to the same server as ReportAIClient (`ABAReportServerHost`), but on the independent
// `/auth/*` route namespace — it does not use the shared REPORT_SERVER_TOKEN. See
// Server/auth.mjs and the Turso schema notes in Server/README.md for the server side.
enum TherapistAuthClient {
    private static func endpoint(_ path: String) throws -> URL {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "ABAReportServerHost") as? String,
              !host.isEmpty, !host.hasSuffix(".invalid"),
              let url = URL(string: "https://\(host)/auth/\(path)") else {
            throw NSError(domain: "TherapistAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "배포 빌드에 등록된 HTTPS 서버 주소를 확인하세요."])
        }
        return url
    }

    private static func makeSession() -> URLSession {
        URLSession(configuration: .ephemeral, delegate: ReportNoRedirect(), delegateQueue: nil)
    }

    private static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "TherapistAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "서버 응답을 확인할 수 없습니다."])
        }
        return (data, http)
    }

    private static func jsonRequest(_ url: URL, method: String, body: [String: Any], bearer: String? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Sign up

    static func signUp(email: String, password: String) async throws {
        guard password.count >= 10 else {
            throw NSError(domain: "TherapistAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "비밀번호는 10자 이상이어야 합니다."])
        }
        let profileKeySalt = TherapistProfileCrypto.randomProfileKeySalt()
        let profileKey = TherapistProfileCrypto.deriveProfileKey(password: password, profileKeySalt: profileKeySalt)
        let (ciphertext, nonce) = try TherapistProfileCrypto.encrypt(.empty, key: profileKey)

        let request = try jsonRequest(try endpoint("signup"), method: "POST", body: [
            "email": email,
            "password": password,
            "profileKeySalt": profileKeySalt.base64EncodedString(),
            "profileCiphertext": ciphertext.base64EncodedString(),
            "profileNonce": nonce.base64EncodedString(),
        ])
        let (_, http) = try await send(request)
        guard http.statusCode == 201 else {
            throw NSError(domain: "TherapistAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: signUpErrorMessage(for: http.statusCode)])
        }
    }

    private static func signUpErrorMessage(for status: Int) -> String {
        switch status {
        case 409: return "이미 가입된 이메일입니다."
        case 422: return "이메일 또는 비밀번호 형식을 확인하세요."
        default: return "가입에 실패했습니다. 잠시 후 다시 시도하세요."
        }
    }

    // MARK: - Email verification

    static func verifyEmail(email: String, code: String) async throws {
        let request = try jsonRequest(try endpoint("verify-email"), method: "POST", body: ["email": email, "code": code])
        let (_, http) = try await send(request)
        guard http.statusCode == 200 else {
            let message: String
            switch http.statusCode {
            case 410: message = "인증 코드가 만료되었습니다. 다시 가입해 주세요."
            case 429: message = "인증 시도 횟수를 초과했습니다."
            case 422: message = "인증 코드가 올바르지 않습니다."
            default: message = "이메일 인증에 실패했습니다."
            }
            throw NSError(domain: "TherapistAuth", code: 5, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // MARK: - Login

    static func login(email: String, password: String) async throws -> TherapistSession {
        let request = try jsonRequest(try endpoint("login"), method: "POST", body: ["email": email, "password": password])
        let (data, http) = try await send(request)
        guard http.statusCode == 200 else {
            let message: String
            switch http.statusCode {
            case 401: message = "이메일 또는 비밀번호가 올바르지 않습니다."
            case 403: message = "이메일 인증을 먼저 완료하세요."
            default: message = "로그인에 실패했습니다."
            }
            throw NSError(domain: "TherapistAuth", code: 6, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionToken = body["sessionToken"] as? String,
              let profileKeySaltB64 = body["profileKeySalt"] as? String,
              let profileCiphertextB64 = body["profileCiphertext"] as? String,
              let profileNonceB64 = body["profileNonce"] as? String,
              let profileKeySalt = Data(base64Encoded: profileKeySaltB64),
              let profileCiphertext = Data(base64Encoded: profileCiphertextB64),
              let profileNonce = Data(base64Encoded: profileNonceB64) else {
            throw NSError(domain: "TherapistAuth", code: 7, userInfo: [NSLocalizedDescriptionKey: "서버 응답 형식이 올바르지 않습니다."])
        }

        let profileKey = TherapistProfileCrypto.deriveProfileKey(password: password, profileKeySalt: profileKeySalt)
        let profile = try TherapistProfileCrypto.decrypt(ciphertextAndTag: profileCiphertext, nonce: profileNonce, key: profileKey)

        try TherapistAuthKeychain.saveSession(token: sessionToken, profileKeySalt: profileKeySalt, profileKey: profileKey)
        try TherapistAuthKeychain.saveCachedProfile(profile)
        return TherapistSession(profile: profile)
    }

    // MARK: - Profile update (requires an active session)

    static func updateProfile(_ profile: TherapistProfile) async throws {
        guard let token = TherapistAuthKeychain.sessionToken(), let profileKey = TherapistAuthKeychain.profileKey() else {
            throw NSError(domain: "TherapistAuth", code: 8, userInfo: [NSLocalizedDescriptionKey: "로그인이 필요합니다."])
        }
        let (ciphertext, nonce) = try TherapistProfileCrypto.encrypt(profile, key: profileKey)
        let request = try jsonRequest(try endpoint("profile"), method: "PUT", body: [
            "profileCiphertext": ciphertext.base64EncodedString(),
            "profileNonce": nonce.base64EncodedString(),
        ], bearer: token)
        let (_, http) = try await send(request)
        guard http.statusCode == 200 else {
            throw NSError(domain: "TherapistAuth", code: 9, userInfo: [NSLocalizedDescriptionKey: "프로필 저장에 실패했습니다."])
        }
        try TherapistAuthKeychain.saveCachedProfile(profile)
    }

    // MARK: - Logout

    static func logout() async {
        if let token = TherapistAuthKeychain.sessionToken(), let url = try? endpoint("logout") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await send(request)
        }
        TherapistAuthKeychain.clear()
    }
}

// Keychain storage for the logged-in therapist. `profileKey` sits alongside the session token so
// the app doesn't need the password again on every launch to read/edit the profile — the same
// device-only tradeoff ReportAIClient already makes for the Groq key.
enum TherapistAuthKeychain {
    private static let service = "kr.abaprogress.therapist"

    private static func item(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func save(_ data: Data, account: String) throws {
        let update = SecItemUpdate(item(account: account) as CFDictionary,
            [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else {
            throw NSError(domain: "TherapistAuth", code: 10, userInfo: [NSLocalizedDescriptionKey: "기기에 안전하게 저장하지 못했습니다."])
        }
        var newItem = item(account: account)
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess else {
            throw NSError(domain: "TherapistAuth", code: 10, userInfo: [NSLocalizedDescriptionKey: "기기에 안전하게 저장하지 못했습니다."])
        }
    }

    private static func load(account: String) -> Data? {
        var query = item(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func delete(account: String) {
        SecItemDelete(item(account: account) as CFDictionary)
    }

    static func saveSession(token: String, profileKeySalt: Data, profileKey: SymmetricKey) throws {
        try save(Data(token.utf8), account: "session-token")
        try save(profileKeySalt, account: "profile-key-salt")
        try save(profileKey.withUnsafeBytes { Data($0) }, account: "profile-key")
    }

    static func sessionToken() -> String? {
        load(account: "session-token").map { String(decoding: $0, as: UTF8.self) }
    }

    static func profileKey() -> SymmetricKey? {
        load(account: "profile-key").map { SymmetricKey(data: $0) }
    }

    static func saveCachedProfile(_ profile: TherapistProfile) throws {
        try save(try JSONEncoder().encode(profile), account: "cached-profile")
    }

    static func cachedProfile() -> TherapistProfile? {
        load(account: "cached-profile").flatMap { try? JSONDecoder().decode(TherapistProfile.self, from: $0) }
    }

    static func isLoggedIn() -> Bool {
        sessionToken() != nil
    }

    static func clear() {
        for account in ["session-token", "profile-key-salt", "profile-key", "cached-profile"] {
            delete(account: account)
        }
    }
}
