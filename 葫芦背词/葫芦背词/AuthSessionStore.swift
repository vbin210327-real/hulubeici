import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var lastError: String?

    private let authService = SupabaseAuthService()
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

    func signIn(email: String, password: String) async throws {
        lastError = nil
        let sanitizedEmail = try EmailValidator.validate(email)
        let sanitizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSession = try await authService.signIn(email: sanitizedEmail, password: sanitizedPassword)
        session = newSession
        persist(session: newSession)
    }

    func requestEmailOTP(email: String) async throws {
        lastError = nil
        let sanitizedEmail = try EmailValidator.validate(email)
        try EmailDeliveryGuard.validateDeliveryAllowed()
        try await authService.sendEmailOTP(email: sanitizedEmail)
    }

    func signInWithEmailOTP(email: String, code: String) async throws {
        lastError = nil
        let sanitizedEmail = try EmailValidator.validate(email)
        let sanitizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSession = try await authService.signInWithEmailOTP(email: sanitizedEmail, code: sanitizedCode)
        session = newSession
        persist(session: newSession)
    }

    func refreshSession() async throws {
        guard let currentSession = session else {
            throw NSError(domain: "AuthSessionStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session to refresh"])
        }

        let newSession = try await authService.refreshToken(refreshToken: currentSession.refreshToken)
        session = newSession
        persist(session: newSession)
    }

    func signOut() {
        guard let currentSession = session else { return }
        Task {
            do {
                try await authService.signOut(accessToken: currentSession.accessToken)
            } catch {
                // Swallow network errors on logout; session will still be cleared locally.
            }
        }
        session = nil
        persist(session: nil)
    }

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
