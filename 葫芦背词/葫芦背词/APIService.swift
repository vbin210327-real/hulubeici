import Foundation

class APIService {
    static let shared = APIService()
    private let client = NetworkClient.shared

    private init() {}

    // MARK: - Profile API

    func getProfile() async throws -> ProfileResponse {
        try await client.get(APIConfig.Endpoints.profile)
    }

    func updateProfile(displayName: String?, avatarEmoji: String?) async throws -> ProfileResponse {
        let payload = ProfileUpdatePayload(displayName: displayName, avatarEmoji: avatarEmoji)
        return try await client.patch(APIConfig.Endpoints.profile, body: payload)
    }

    // MARK: - Wordbooks API

    func getWordbooks() async throws -> WordbooksResponse {
        try await client.get(APIConfig.Endpoints.wordbooks)
    }

    func createWordbook(
        title: String,
        subtitle: String?,
        targetPasses: Int,
        entries: [WordEntryPayload]
    ) async throws -> WordbookDetailResponse {
        let payload = CreateWordbookPayload(
            title: title,
            subtitle: subtitle,
            targetPasses: targetPasses,
            entries: entries
        )
        return try await client.post(APIConfig.Endpoints.wordbooks, body: payload)
    }

    func getWordbook(id: String) async throws -> WordbookDetailResponse {
        try await client.get(APIConfig.Endpoints.wordbook(id: id))
    }

    func updateWordbook(
        id: String,
        title: String?,
        subtitle: String?,
        targetPasses: Int?,
        entries: [WordEntryPayload]?
    ) async throws -> WordbookDetailResponse {
        let payload = UpdateWordbookPayload(
            title: title,
            subtitle: subtitle,
            targetPasses: targetPasses,
            entries: entries
        )
        return try await client.patch(APIConfig.Endpoints.wordbook(id: id), body: payload)
    }

    func deleteWordbook(id: String) async throws -> DeleteResponse {
        try await client.delete(APIConfig.Endpoints.wordbook(id: id))
    }

    // MARK: - Progress API

    func getSectionProgress() async throws -> SectionProgressResponse {
        try await client.get(APIConfig.Endpoints.sectionProgress)
    }

    func updateSectionProgress(items: [SectionProgressItem]) async throws -> SectionProgressResponse {
        let payload = SectionProgressPayload(progress: items)
        return try await client.post(APIConfig.Endpoints.sectionProgress, body: payload)
    }

    func getDailyProgress(startDate: String?, endDate: String?) async throws -> DailyProgressResponse {
        var endpoint = APIConfig.Endpoints.dailyProgress
        var queryItems: [String] = []

        if let start = startDate {
            queryItems.append("start_date=\(start)")
        }
        if let end = endDate {
            queryItems.append("end_date=\(end)")
        }

        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }

        return try await client.get(endpoint)
    }

    func updateDailyProgress(items: [DailyProgressItem]) async throws -> DailyProgressResponse {
        let payload = DailyProgressPayload(progress: items)
        return try await client.post(APIConfig.Endpoints.dailyProgress, body: payload)
    }

    // MARK: - Visibility API

    func getVisibility(wordbookIds: [String]?) async throws -> VisibilityResponse {
        var endpoint = APIConfig.Endpoints.visibility

        if let ids = wordbookIds, !ids.isEmpty {
            endpoint += "?wordbook_ids=" + ids.joined(separator: ",")
        }

        return try await client.get(endpoint)
    }

    func updateVisibility(items: [VisibilityItem]) async throws -> VisibilityResponse {
        let payload = VisibilityPayload(visibility: items)
        return try await client.post(APIConfig.Endpoints.visibility, body: payload)
    }
}

// MARK: - Request/Response Models

// Profile
struct ProfileResponse: Codable {
    let profile: ProfileData
}

struct ProfileData: Codable {
    let displayName: String
    let avatarEmoji: String
    let updatedAt: String?
}

struct ProfileUpdatePayload: Codable {
    let displayName: String?
    let avatarEmoji: String?
}

// Wordbooks
struct WordbooksResponse: Codable {
    let wordbooks: [WordbookSummary]
}

struct WordbookSummary: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let targetPasses: Int
    let wordCount: Int
    let isTemplate: Bool
    let createdAt: String
    let updatedAt: String
}

struct WordbookDetailResponse: Codable {
    let wordbook: WordbookDetail
}

struct WordbookDetail: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let targetPasses: Int
    let isTemplate: Bool
    let createdAt: String
    let updatedAt: String
    let entries: [WordEntryData]
}

struct WordEntryData: Codable {
    let id: String
    let lemma: String
    let definition: String
    let ordinal: Int
}

struct CreateWordbookPayload: Codable {
    let title: String
    let subtitle: String?
    let targetPasses: Int
    let entries: [WordEntryPayload]
}

struct UpdateWordbookPayload: Codable {
    let title: String?
    let subtitle: String?
    let targetPasses: Int?
    let entries: [WordEntryPayload]?
}

struct WordEntryPayload: Codable {
    let id: String?
    let word: String
    let meaning: String
    let ordinal: Int?
}

struct DeleteResponse: Codable {
    let success: Bool
}

// Progress
struct SectionProgressResponse: Codable {
    let progress: [SectionProgressData]
}

struct SectionProgressData: Codable {
    let wordbookId: String
    let completedPages: Int
    let completedPasses: Int
    let updatedAt: String
}

struct SectionProgressPayload: Codable {
    let progress: [SectionProgressItem]
}

struct SectionProgressItem: Codable {
    let wordbookId: String
    let completedPages: Int
    let completedPasses: Int
}

struct DailyProgressResponse: Codable {
    let progress: [DailyProgressData]
}

struct DailyProgressData: Codable {
    let progressDate: String
    let wordsLearned: Int
    let updatedAt: String
}

struct DailyProgressPayload: Codable {
    let progress: [DailyProgressItem]
}

struct DailyProgressItem: Codable {
    let progressDate: String
    let wordsLearned: Int
}

// Visibility
struct VisibilityResponse: Codable {
    let visibility: [VisibilityData]
}

struct VisibilityData: Codable {
    let wordEntryId: String
    let showWord: Bool
    let showMeaning: Bool
    let updatedAt: String
}

struct VisibilityPayload: Codable {
    let visibility: [VisibilityItem]
}

struct VisibilityItem: Codable {
    let wordEntryId: String
    let showWord: Bool
    let showMeaning: Bool
}
