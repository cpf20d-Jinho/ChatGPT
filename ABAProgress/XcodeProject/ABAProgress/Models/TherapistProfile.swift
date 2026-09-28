import Foundation

// Therapist account profile. This is the only personal-data category that ever leaves the
// device — child profiles, sessions, trials and reports stay in local SwiftData. The server only
// ever sees this struct after it has been AES-256-GCM encrypted client-side (see
// TherapistAuthCrypto.swift); it cannot decrypt it.
struct TherapistProfile: Codable, Equatable {
    var name: String
    var centerName: String
    var centerAddress: String
    var phoneNumber: String
    var licenseNumber: String

    static let empty = TherapistProfile(name: "", centerName: "", centerAddress: "", phoneNumber: "", licenseNumber: "")
}
