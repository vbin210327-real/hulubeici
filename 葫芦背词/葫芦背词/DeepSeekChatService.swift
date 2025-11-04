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
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        let choices: [Choice]
    }

    private let continuationPrompt = "请从上次中断的地方继续回答，保持相同的语言和格式，不要重复已经输出的内容。"
    private let maxContinuationSegments = 6

    func send(messages: [AIChatMessage]) async throws -> AIChatMessage {
        guard let apiKey = Secrets.shared.deepSeekAPIKey, !apiKey.isEmpty else {
            throw DeepSeekChatServiceError.missingAPIKey
        }

        var conversation = messages
        var aggregatedContent = ""
        var segments = 0

        while segments < maxContinuationSegments {
            let choice = try await performRequest(messages: conversation, apiKey: apiKey)
            aggregatedContent += choice.message.content

            let finishReason = choice.finishReason?.lowercased()
            guard finishReason == "length" else {
                break
            }

            conversation.append(
                AIChatMessage(role: .assistant, content: choice.message.content)
            )
            conversation.append(
                AIChatMessage(role: .user, content: continuationPrompt)
            )
            segments += 1
        }

        if aggregatedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DeepSeekChatServiceError.missingMessage
        }

        if segments >= maxContinuationSegments {
            aggregatedContent += "\n\n（提示：回复极长，已自动续写多次。如需继续，请告诉我“继续”，我会再接着输出。）"
        }

        return AIChatMessage(
            role: .assistant,
            content: aggregatedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func performRequest(messages: [AIChatMessage], apiKey: String) async throws -> DeepSeekChatResponse.Choice {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = DeepSeekChatRequest(
            model: model,
            messages: messages.map { DeepSeekChatRequest.Message(role: $0.role.rawValue, content: $0.content) },
            maxTokens: nil,
            temperature: 0.7
        )

        request.httpBody = try JSONEncoder().encode(payload)
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
        guard let choice = decoded.choices.first else {
            throw DeepSeekChatServiceError.missingMessage
        }
        return choice
    }
}
