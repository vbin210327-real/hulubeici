import Foundation

enum AIChatRole: String, Codable {
    case system
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AIChatRole
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: AIChatRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum DeepSeekChatServiceError: LocalizedError {
    case invalidResponse
    case missingMessage
    case httpStatus(Int, String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务响应格式异常。"
        case .missingMessage:
            return "未收到模型回复，请稍后再试。"
        case .httpStatus(let status, let message):
            return "请求失败 (\(status))：\(message)"
        case .missingAPIKey:
            return "DeepSeek API 密钥缺失，请先在 Secrets.plist 中配置。"
        }
    }
}

final class DeepSeekChatService {
    static let shared = DeepSeekChatService()
    private init() {}

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"

    struct DeepSeekErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }

        let error: APIError
    }

    struct DeepSeekChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let maxTokens: Int?
        let temperature: Double?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case maxTokens = "max_tokens"
            case temperature
        }
    }

    struct DeepSeekChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    func send(messages: [AIChatMessage]) async throws -> AIChatMessage {
        guard let apiKey = Secrets.shared.deepSeekAPIKey, !apiKey.isEmpty else {
            throw DeepSeekChatServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = DeepSeekChatRequest(
            model: model,
            messages: messages.map { DeepSeekChatRequest.Message(role: $0.role.rawValue, content: $0.content) },
            maxTokens: 512,
            temperature: 0.7
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekChatServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? JSONDecoder().decode(DeepSeekErrorEnvelope.self, from: data) {
                throw DeepSeekChatServiceError.httpStatus(httpResponse.statusCode, envelope.error.message)
            } else {
                throw DeepSeekChatServiceError.httpStatus(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
            }
        }

        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let reply = decoded.choices.first?.message else {
            throw DeepSeekChatServiceError.missingMessage
        }

        return AIChatMessage(role: AIChatRole(rawValue: reply.role) ?? .assistant, content: reply.content)
    }
}
