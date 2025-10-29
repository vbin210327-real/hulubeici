import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
    let email: String?

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

#if DEBUG
extension AuthSession {
    static let preview = AuthSession(
        accessToken: "preview-token",
        refreshToken: "preview-refresh",
        expiresAt: Date().addingTimeInterval(3600),
        userId: "preview-user",
        email: "preview@example.com"
    )
}
#endif
