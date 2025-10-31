import Foundation

enum EmailValidator {
    enum ValidationError: LocalizedError, Equatable {
        case empty
        case invalidFormat
        case invalidCharacters
        case localPartTooLong
        case emailTooLong
        case domainInvalid
        case domainBlocked
        case suspectedTypo(suggestion: String)

        var errorDescription: String? {
            EmailValidator.userFacingErrorMessage
        }
    }

    private static let maxEmailLength = 254
    private static let maxLocalPartLength = 64
    private static let localAllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "!#$%&'*+/=?^_`{|}~-")
        return set
    }()
    private static let blockedDomains: Set<String> = [
        "example.com", "example.org", "example.net",
        "test.com", "test.org", "test.net",
        "mailinator.com", "mailinator.org", "mailinator.net",
        "tempmail.com", "tempmail.net", "tempmail.org",
        "10minutemail.com", "guerrillamail.com", "trashmail.com",
        "fakeinbox.com", "dispostable.com"
    ]
    private static let blockedSuffixes: [String] = [
        ".invalid", ".example", ".test", ".localhost", ".local"
    ]
    private static let commonDomainTypos: [String: String] = [
        "gmail.con": "gmail.com",
        "gmail.co": "gmail.com",
        "gmail.cmo": "gmail.com",
        "hotmail.con": "hotmail.com",
        "hotmail.co": "hotmail.com",
        "outlook.con": "outlook.com",
        "outlook.co": "outlook.com",
        "icloud.con": "icloud.com",
        "icloud.co": "icloud.com",
        "yahoo.con": "yahoo.com"
    ]
    private static let userFacingErrorMessage = "请输入正确的邮箱地址。"

    static func validate(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard trimmed.count <= maxEmailLength else { throw ValidationError.emailTooLong }
        guard let atIndex = trimmed.firstIndex(of: "@") else { throw ValidationError.invalidFormat }
        if trimmed[trimmed.index(after: atIndex)...].contains("@") {
            throw ValidationError.invalidFormat
        }

        let localPart = String(trimmed[..<atIndex])
        let domainPart = String(trimmed[trimmed.index(after: atIndex)...])

        guard !localPart.isEmpty, !domainPart.isEmpty else { throw ValidationError.invalidFormat }
        guard localPart.count <= maxLocalPartLength else { throw ValidationError.localPartTooLong }
        guard !localPart.hasPrefix("."),
              !localPart.hasSuffix("."),
              !localPart.contains("..") else {
            throw ValidationError.invalidFormat
        }

        var allowed = localAllowedCharacters
        allowed.insert(charactersIn: ".")
        if localPart.rangeOfCharacter(from: allowed.inverted) != nil {
            throw ValidationError.invalidCharacters
        }

        let domainLower = domainPart.lowercased()
        guard domainLower.contains(".") else { throw ValidationError.domainInvalid }

        let labels = domainLower.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { throw ValidationError.domainInvalid }

        for label in labels {
            guard !label.isEmpty else { throw ValidationError.domainInvalid }
            guard label.count <= 63 else { throw ValidationError.domainInvalid }
            guard !label.hasPrefix("-"), !label.hasSuffix("-") else { throw ValidationError.domainInvalid }
            if label.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted) != nil {
                throw ValidationError.domainInvalid
            }
        }

        if let tld = labels.last {
            guard tld.count >= 2, tld.count <= 24 else { throw ValidationError.domainInvalid }
            guard tld.allSatisfy({ $0.isLetter }) else { throw ValidationError.domainInvalid }
        }

        if blockedDomains.contains(domainLower) || blockedSuffixes.contains(where: { domainLower.hasSuffix($0) }) {
            throw ValidationError.domainBlocked
        }

        if let suggestion = commonDomainTypos[domainLower] {
            throw ValidationError.suspectedTypo(suggestion: suggestion)
        }

        return "\(localPart)@\(domainLower)"
    }

    static func validationError(for rawValue: String) -> ValidationError? {
        do {
            _ = try validate(rawValue)
            return nil
        } catch let error as ValidationError {
            return error
        } catch {
            return .invalidFormat
        }
    }

    static func isLikelyDeliverable(_ rawValue: String) -> Bool {
        (try? validate(rawValue)) != nil
    }
}
