import Foundation

enum AppEntitlements {
    // Free tier limits
    static let freeCustomWordbookLimit = 2
    static let freeDailyAIMessageLimit = 20

    // Product IDs (configure in App Store Connect)
    enum ProductID {
        // Create these in App Store Connect with pricing: ¥9/月, ¥70/年
        static let premiumMonthly = "com.hulubeici.plus.monthly"
        static let premiumYearly = "com.hulubeici.pro.yearly"
    }
}
