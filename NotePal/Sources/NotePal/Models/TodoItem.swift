import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String?
    var isCompleted: Bool
    var dueDate: Date?
    var wellnessKind: String?
    var wellnessReminderIntervalMinutes: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "新待办",
        description: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        wellnessKind: String? = nil,
        wellnessReminderIntervalMinutes: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.wellnessKind = wellnessKind
        self.wellnessReminderIntervalMinutes = wellnessReminderIntervalMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isWellnessTodo: Bool {
        wellnessKind != nil
    }

    var effectiveWellnessIntervalMinutes: Int {
        max(5, wellnessReminderIntervalMinutes ?? 60)
    }

    var reminderRevisionKey: String {
        let dueStamp = dueDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none"
        let updatedStamp = String(Int(updatedAt.timeIntervalSince1970 * 1000))
        guard isWellnessTodo else {
            return "v2|\(id.uuidString)|\(dueStamp)|\(updatedStamp)"
        }

        let wellnessStamp = wellnessKind ?? "regular"
        let intervalStamp = wellnessReminderIntervalMinutes.map(String.init) ?? "none"
        return "v3|\(id.uuidString)|\(dueStamp)|\(updatedStamp)|\(wellnessStamp)|\(intervalStamp)"
    }

    func isDue(asOf date: Date) -> Bool {
        guard let dueDate, !isCompleted else {
            return false
        }

        return dueDate <= date
    }
}
