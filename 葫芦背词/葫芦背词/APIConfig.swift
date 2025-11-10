import Foundation

enum APIConfig {
    // App sync configuration
    struct AppSyncConfig {
        // Enable CloudKit iCloud sync
        static let iCloudEnabled: Bool = true
        static let iCloudContainerID: String = "iCloud.com.hulubeici"
    }
}
