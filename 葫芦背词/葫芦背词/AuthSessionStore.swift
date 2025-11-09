import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var lastError: String?

    // Backend auth removed in iCloud mode
    private let storageKey = "SupabaseAuthSession.v1"
    private let defaults: UserDefaults

    var isAuthenticated: Bool {
        session != nil
    }

    init(userDefaults: UserDefaults = .standard, initialSession: AuthSession? = nil) {
        self.defaults = userDefaults
        if let initialSession {
            session = initialSession
        } else if let stored = Self.restore(from: storageKey, defaults: userDefaults) {
            session = stored
        }
    }

    func signIn(email: String, password: String) async throws { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Email sign-in disabled. Using iCloud sync."]) }

    func requestEmailOTP(email: String) async throws { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "OTP disabled. Using iCloud sync."]) }

    func signInWithEmailOTP(email: String, code: String) async throws { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "OTP disabled. Using iCloud sync."]) }

    func refreshSession() async throws { }

    func signOut() { session = nil; persist(session: nil) }

    func clearErrors() {
        lastError = nil
    }

    // MARK: - Persistence

    private func persist(session: AuthSession?) {
        if let session {
            if let data = try? JSONEncoder().encode(session) {
                defaults.set(data, forKey: storageKey)
            }
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    private static func restore(from key: String, defaults: UserDefaults) -> AuthSession? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
}
