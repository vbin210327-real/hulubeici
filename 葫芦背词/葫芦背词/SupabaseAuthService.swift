import Foundation

struct SupabaseAuthService {
    private struct SignInResponse: Decodable {
        struct UserResponse: Decodable {
            let id: String
            let email: String?
        }

        let accessToken: String
        let expiresIn: Double
        let refreshToken: String
        let tokenType: String
        let user: UserResponse

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case user
        }

        func makeSession() -> AuthSession {
            let expiry = Date().addingTimeInterval(expiresIn)
            return AuthSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiry,
                userId: user.id,
                email: user.email
            )
        }
    }
    private struct SessionPayload: Decodable {
        let accessToken: String?
        let expiresIn: Double?
        let refreshToken: String?
        let tokenType: String?
        let user: SignInResponse.UserResponse?

        func makeSession() throws -> AuthSession {
            guard
                let accessToken,
                let refreshToken,
                let expiresIn,
                let user
            else {
                throw SupabaseAuthService.AuthError.decoding
            }
            let expiry = Date().addingTimeInterval(expiresIn)
            return AuthSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiry,
                userId: user.id,
                email: user.email
            )
        }
    }

    private struct SessionWrapperResponse: Decodable {
        let accessToken: String?
        let expiresIn: Double?
        let refreshToken: String?
        let tokenType: String?
        let user: SignInResponse.UserResponse?
        let session: SessionPayload?

        var sessionFromTopLevel: SessionPayload? {
            guard
                let accessToken,
                let refreshToken,
                let expiresIn,
                let user
            else {
                return nil
            }
            return SessionPayload(
                accessToken: accessToken,
                expiresIn: expiresIn,
                refreshToken: refreshToken,
                tokenType: tokenType,
                user: user
            )
        }

        var containsUserWithoutSession: Bool {
            user != nil && session == nil && accessToken == nil && refreshToken == nil
        }
    }

    enum AuthError: Error, LocalizedError {
        case invalidCredentials
        case invalidOTP
        case service(String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "邮箱或密码不正确。"
            case .invalidOTP:
                return "验证码不正确或已过期。"
            case .service(let message):
                return message
            case .decoding:
                return "解析登录响应失败。"
            }
        }
    }

    private let baseURL = SupabaseConfig.url
    private let anonKey = SupabaseConfig.anonKey
    private let urlSession: URLSession = .shared

    func signIn(email: String, password: String) async throws -> AuthSession {
        var components = URLComponents(url: baseURL.appendingPathComponent("/auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        guard let url = components?.url else {
            throw AuthError.service("无法构建登录请求。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue(anonKey, forHTTPHeaderField: "Authorization")

        let body = [
            "email": email,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw AuthError.invalidCredentials
            }
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AuthError.service(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let result = try? decoder.decode(SignInResponse.self, from: data) else {
            throw AuthError.decoding
        }

        let expiry = Date().addingTimeInterval(result.expiresIn)
        return AuthSession(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            expiresAt: expiry,
            userId: result.user.id,
            email: result.user.email
        )
    }

    func sendEmailOTP(email: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/otp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue(anonKey, forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "email": email,
            "type": "email",
            "create_user": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 429 {
                throw AuthError.service("请求过于频繁，请稍后再试。")
            }
            if let message = extractErrorMessage(from: data) {
                throw AuthError.service(message)
            }
            throw AuthError.service("发送验证码失败。")
        }
    }

    func signInWithEmailOTP(email: String, code: String) async throws -> AuthSession {
        guard let sanitizedCode = sanitizeOTP(code) else {
            throw AuthError.invalidOTP
        }

        let url = baseURL.appendingPathComponent("/auth/v1/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue(anonKey, forHTTPHeaderField: "Authorization")

        let body = [
            "email": email,
            "token": sanitizedCode,
            "type": "email"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard (200..<300).contains(httpResponse.statusCode) else {
                if let message = extractErrorMessage(from: data), !message.isEmpty {
                    if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                        throw AuthError.service(message)
                    }
                    throw AuthError.service(message)
                }
                if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    throw AuthError.invalidOTP
                }
                let message = String(data: data, encoding: .utf8) ?? "未知错误"
                throw AuthError.service(message)
            }
        }

        return try parseSessionResponse(data: data)
    }

    func refreshToken(refreshToken: String) async throws -> AuthSession {
        var components = URLComponents(url: baseURL.appendingPathComponent("/auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        guard let url = components?.url else {
            throw AuthError.service("无法构建刷新请求。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue(anonKey, forHTTPHeaderField: "Authorization")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw AuthError.invalidCredentials
            }
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AuthError.service(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let result = try? decoder.decode(SignInResponse.self, from: data) else {
            throw AuthError.decoding
        }

        let expiry = Date().addingTimeInterval(result.expiresIn)
        return AuthSession(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            expiresAt: expiry,
            userId: result.user.id,
            email: result.user.email
        )
    }

    func signOut(accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AuthError.service("注销失败（\(httpResponse.statusCode)）。")
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }

        if let message = dictionary["message"] as? String, !message.isEmpty {
            return message
        }
        if let description = dictionary["error_description"] as? String, !description.isEmpty {
            return description
        }
        if let error = dictionary["error"] as? String, !error.isEmpty {
            return error
        }
        return nil
    }

    private func extractConfirmationMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }

        if let message = dictionary["message"] as? String, !message.isEmpty {
            return message
        }
        if let title = dictionary["title"] as? String, !title.isEmpty {
            return title
        }
        return nil
    }

    private func sanitizeOTP(_ code: String) -> String? {
        let digits = code.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        let sanitized = String(String.UnicodeScalarView(digits))
        return sanitized.isEmpty ? nil : sanitized
    }

    private func parseSessionResponse(data: Data) throws -> AuthSession {
        guard !data.isEmpty else {
            throw AuthError.service("服务器未返回登录凭据，请稍后重试。")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let direct = try? decoder.decode(SignInResponse.self, from: data) {
            return direct.makeSession()
        }

        if let wrapped = try? decoder.decode(SessionWrapperResponse.self, from: data) {
            if let payload = wrapped.session ?? wrapped.sessionFromTopLevel {
                return try payload.makeSession()
            }

            if wrapped.containsUserWithoutSession {
                throw AuthError.service("Supabase 没有返回访问令牌。请在 Supabase Auth 设置中启用 Email OTP 会话返回，或尝试使用密码登录。")
            }
        }

        if let message = extractConfirmationMessage(from: data) {
            throw AuthError.service(message)
        }

        if let stringValue = String(data: data, encoding: .utf8),
           !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AuthError.service(stringValue)
        }

        throw AuthError.decoding
    }
}
