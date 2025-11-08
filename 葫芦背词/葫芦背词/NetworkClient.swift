import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(String)
    case networkError(Error)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "服务器返回空数据"
        case .decodingError:
            return "数据解析失败"
        case .unauthorized:
            return "未授权，请重新登录"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addHeaders(to: &request, additional: headers)

        return try await performRequest(request)
    }

    func post<T: Decodable, U: Encodable>(
        _ endpoint: String,
        body: U,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        try await addHeaders(to: &request, additional: headers)

        return try await performRequest(request)
    }

    func patch<T: Decodable, U: Encodable>(
        _ endpoint: String,
        body: U,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try encoder.encode(body)
        try await addHeaders(to: &request, additional: headers)

        return try await performRequest(request)
    }

    func delete<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await addHeaders(to: &request, additional: headers)

        return try await performRequest(request)
    }

    // MARK: - Helper Methods

    private func buildURL(_ endpoint: String) throws -> URL {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        return url
    }

    private func addHeaders(to request: inout URLRequest, additional: [String: String]?) async throws {
        // Add content type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let accessToken = try await getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Add any additional headers
        if let additionalHeaders = additional {
            for (key, value) in additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }

    private func getAccessToken() async throws -> String? {
        // Read session from UserDefaults
        let storageKey = "SupabaseAuthSession.v1"
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("🔐 No session data found in UserDefaults")
            return nil
        }

        guard var session = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            print("🔐 Failed to decode session from UserDefaults")
            return nil
        }

        // Check if token is expired or expiring soon (within 5 minutes)
        let expiryThreshold = Date().addingTimeInterval(300) // 5 minutes
        if session.expiresAt <= expiryThreshold {
            print("⚠️ Access token is expired or expiring soon. Attempting refresh...")

            // Attempt to refresh the token
            do {
                let authService = SupabaseAuthService()
                let newSession = try await authService.refreshToken(refreshToken: session.refreshToken)

                // Save the new session
                if let encodedSession = try? JSONEncoder().encode(newSession) {
                    UserDefaults.standard.set(encodedSession, forKey: storageKey)
                    print("✅ Token refreshed successfully")
                }

                session = newSession
            } catch {
                print("❌ Failed to refresh token: \(error.localizedDescription)")
                // Return nil to trigger 401 error
                return nil
            }
        }

        print("🔐 Access token found: \(session.accessToken.prefix(20))...")
        return session.accessToken
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            // Log request details
            print("🌐 Request: \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
            if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                print("🌐 Auth: \(authHeader.prefix(30))...")
            } else {
                print("🌐 Auth: None")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverError("Invalid response")
            }

            print("🌐 Response: \(httpResponse.statusCode)")

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode and return
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw NetworkError.decodingError
                }

            case 401:
                // Unauthorized - user needs to login again
                throw NetworkError.unauthorized

            case 400...499:
                // Client error - try to parse error message
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.error ?? "客户端错误")
                } else {
                    throw NetworkError.serverError("客户端错误 (\(httpResponse.statusCode))")
                }

            case 500...599:
                // Server error
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.error ?? "服务器错误")
                } else {
                    throw NetworkError.serverError("服务器错误 (\(httpResponse.statusCode))")
                }

            default:
                throw NetworkError.serverError("未知错误 (\(httpResponse.statusCode))")
            }

        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

// MARK: - Response Models

struct ErrorResponse: Codable {
    let error: String?
    let details: String?
}
