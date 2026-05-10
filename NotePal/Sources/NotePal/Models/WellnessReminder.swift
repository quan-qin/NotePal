import Foundation

struct WellnessReminder: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case drinkWater
        case standKegel
        case lookFar

        var title: String {
            switch self {
            case .drinkWater:
                return "提醒喝水"
            case .standKegel:
                return "提醒站立提肛"
            case .lookFar:
                return "远眺养眼"
            }
        }

        var message: String {
            switch self {
            case .drinkWater:
                return "该喝点水了。"
            case .standKegel:
                return "站起来活动一下，做一组提肛。"
            case .lookFar:
                return "远眺一下，放松眼睛。"
            }
        }
    }

    var kind: Kind
    var isEnabled: Bool
    var intervalMinutes: Int
    var nextReminderAt: Date
    var updatedAt: Date

    var id: String {
        kind.rawValue
    }

    var title: String {
        kind.title
    }

    var message: String {
        kind.message
    }

    var effectiveIntervalMinutes: Int {
        min(max(intervalMinutes, 5), 1440)
    }

    init(
        kind: Kind,
        isEnabled: Bool = true,
        intervalMinutes: Int = 60,
        nextReminderAt: Date = Date().addingTimeInterval(3600),
        updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.intervalMinutes = min(max(intervalMinutes, 5), 1440)
        self.nextReminderAt = nextReminderAt
        self.updatedAt = updatedAt
    }

    static func defaults(now: Date = Date()) -> [WellnessReminder] {
        Kind.allCases.map { kind in
            WellnessReminder(
                kind: kind,
                isEnabled: true,
                intervalMinutes: 60,
                nextReminderAt: now.addingTimeInterval(3600),
                updatedAt: now
            )
        }
    }
}
