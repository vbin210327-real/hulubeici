import Foundation

enum EmailDeliveryGuard {
    enum DeliveryError: LocalizedError {
        case sendingDisabled

        var errorDescription: String? {
            "当前构建禁用了邮件发送，请配置有效邮箱或在环境变量中移除 SUPPRESS_SUPABASE_EMAILS。"
        }
    }

    static func validateDeliveryAllowed() throws {
#if DEBUG
        if ProcessInfo.processInfo.environment["SUPPRESS_SUPABASE_EMAILS"] == "1" {
            throw DeliveryError.sendingDisabled
        }
#endif
    }
}
