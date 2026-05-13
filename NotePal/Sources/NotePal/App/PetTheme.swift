import Foundation

enum PetTheme: String, CaseIterable, Identifiable {
    case newton
    case confucius
    case prayerIncenseBurner
    case specialA
    case specialB
    case tao

    var id: String {
        rawValue
    }

    var storedIDs: [String] {
        switch self {
        case .newton, .confucius, .prayerIncenseBurner:
            return [rawValue]
        case .specialA:
            return [rawValue, Self.joined("academic", "Special")]
        case .specialB:
            return [rawValue, Self.joined("wed", "ding", "Special")]
        case .tao:
            return [rawValue]
        }
    }

    var displayName: String {
        switch self {
        case .newton:
            return "Newton"
        case .confucius:
            return "孔子"
        case .prayerIncenseBurner:
            return "祈福香炉"
        case .specialA:
            return "Professor Ai"
        case .specialB:
            return "Dr.ZY & Dr.ZX"
        case .tao:
            return "Professor Tao"
        }
    }

    var resourceName: String {
        switch self {
        case .newton:
            return "Newton"
        case .confucius:
            return "Kongzi"
        case .prayerIncenseBurner:
            return "PrayerIncenseBurner"
        case .specialA:
            return "SpecialThemeA"
        case .specialB:
            return "SpecialThemeB"
        case .tao:
            return "SpecialThemeTao"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .newton:
            return "NotePal 默认形象"
        case .confucius:
            return "NotePal 经典形象"
        case .prayerIncenseBurner:
            return "NotePal 祈福香炉形象"
        case .specialA:
            return "NotePal 特殊形象 A"
        case .specialB:
            return "NotePal 特殊形象 B"
        case .tao:
            return "NotePal GIS 教授特殊形象"
        }
    }

    var isSpecial: Bool {
        switch self {
        case .newton, .confucius, .prayerIncenseBurner:
            return false
        case .specialA, .specialB, .tao:
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
        case .prayerIncenseBurner:
            return "香烟静静升起。"
        case .specialA:
            return "我会安静待在这里。"
        case .specialB:
            return "我会安静待在这里。"
        case .tao:
            return "我先把图层关小声一点。"
        }
    }

    var completionPhrase: String {
        switch self {
        case .newton:
            return "完成一个待办，惯性被你打破了。"
        case .confucius:
            return "温故知新，又进一程。"
        case .prayerIncenseBurner:
            return "愿望又向前走了一步。"
        case .specialA:
            return "完成一个待办。"
        case .specialB:
            return "完成一个待办。"
        case .tao:
            return "又完成一个任务，空间索引都更清爽了。"
        }
    }

    var defaultGreeting: String {
        switch self {
        case .newton:
            return "从一颗苹果开始，也能想到整片天空。"
        case .confucius:
            return "学而时习之，不亦说乎。"
        case .prayerIncenseBurner:
            return "一缕清香，万事顺遂。"
        case .specialA:
            return "最近进展如何？"
        case .specialB:
            return "最近进展如何？"
        case .tao:
            return "今天的空间问题，先从尺度和位置讲起。"
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
