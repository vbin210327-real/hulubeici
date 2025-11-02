import Foundation

final class Secrets {
    static let shared = Secrets()

    private init() {}

    private lazy var values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }

        let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        return plist as? [String: Any] ?? [:]
    }()

    var deepSeekAPIKey: String? {
        values["DeepSeekAPIKey"] as? String
    }
}
