import Foundation

enum PetTheme: String, CaseIterable, Identifiable {
    case newton
    case confucius
    case specialA
    case specialB

    var id: String {
        rawValue
    }

    var storedIDs: [String] {
        switch self {
        case .newton, .confucius:
            return [rawValue]
        case .specialA:
            return [rawValue, Self.joined("academic", "Special")]
        case .specialB:
            return [rawValue, Self.joined("wed", "ding", "Special")]
        }
    }

    var displayName: String {
        switch self {
        case .newton:
            return "Default Theme"
        case .confucius:
            return "Classic Theme"
        case .specialA:
            return "Special Theme A"
        case .specialB:
            return "Special Theme B"
        }
    }

    var resourceName: String {
        switch self {
        case .newton:
            return "Newton"
        case .confucius:
            return "Kongzi"
        case .specialA:
            return "SpecialThemeA"
        case .specialB:
            return "SpecialThemeB"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .newton:
            return "NotePal 默认形象"
        case .confucius:
            return "NotePal 经典形象"
        case .specialA:
            return "NotePal 特殊形象 A"
        case .specialB:
            return "NotePal 特殊形象 B"
        }
    }

    var isSpecial: Bool {
        switch self {
        case .newton, .confucius:
            return false
        case .specialA, .specialB:
            return true
        }
    }

    var publicResourceName: String? {
        isSpecial ? nil : resourceName
    }

    var encryptedResourceName: String? {
        isSpecial ? resourceName : nil
    }

    var sleepyPhrase: String {
        switch self {
        case .newton:
            return "我会安静思考一会儿。"
        case .confucius:
            return "吾少也贱，故多能鄙事。"
        case .specialA:
            return "我会安静待在这里。"
        case .specialB:
            return "我会安静待在这里。"
        }
    }

    var completionPhrase: String {
        switch self {
        case .newton:
            return "完成一个待办，惯性被你打破了。"
        case .confucius:
            return "温故知新，又进一程。"
        case .specialA:
            return "完成一个待办。"
        case .specialB:
            return "完成一个待办。"
        }
    }

    var defaultGreeting: String {
        switch self {
        case .newton:
            return "从一颗苹果开始，也能想到整片天空。"
        case .confucius:
            return "学而时习之，不亦说乎。"
        case .specialA:
            return "最近进展如何？"
        case .specialB:
            return "最近进展如何？"
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case Self.joined("academic", "Special"):
            self = .specialA
        case Self.joined("wed", "ding", "Special"):
            self = .specialB
        default:
            self.init(rawValue: storedValue)
        }
    }

    private static func joined(_ parts: String...) -> String {
        parts.joined()
    }
}
