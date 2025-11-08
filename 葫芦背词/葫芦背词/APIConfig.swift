import Foundation

enum APIConfig {
    // Backend API base URL
    static let baseURL = "https://hulu-beici-backend-248x9h07b-links-projects-570aaf31.vercel.app"

    // API endpoints
    enum Endpoints {
        static let profile = "/api/profile"
        static let wordbooks = "/api/wordbooks"
        static let sectionProgress = "/api/progress/sections"
        static let dailyProgress = "/api/progress/daily"
        static let visibility = "/api/visibility"

        static func wordbook(id: String) -> String {
            "/api/wordbooks/\(id)"
        }

        static func wordbookEntries(id: String) -> String {
            "/api/wordbooks/\(id)/entries"
        }
    }
}
