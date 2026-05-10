import Foundation

struct NotePalData: Codable {
    var notes: [Note]
    var todos: [TodoItem]
    var remindedTodoRevisions: Set<String>
    var wellnessReminders: [WellnessReminder]

    init(
        notes: [Note] = [],
        todos: [TodoItem] = [],
        remindedTodoRevisions: Set<String> = [],
        wellnessReminders: [WellnessReminder] = []
    ) {
        self.notes = notes
        self.todos = todos
        self.remindedTodoRevisions = remindedTodoRevisions
        self.wellnessReminders = wellnessReminders
    }

    enum CodingKeys: String, CodingKey {
        case notes
        case todos
        case remindedTodoRevisions
        case wellnessReminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        remindedTodoRevisions = try container.decodeIfPresent(Set<String>.self, forKey: .remindedTodoRevisions) ?? []
        wellnessReminders = try container.decodeIfPresent([WellnessReminder].self, forKey: .wellnessReminders) ?? []
    }
}
