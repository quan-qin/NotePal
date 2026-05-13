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
        self.notes = Self.migratedNotes(notes)
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
        let decodedNotes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        notes = Self.migratedNotes(decodedNotes)
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        remindedTodoRevisions = try container.decodeIfPresent(Set<String>.self, forKey: .remindedTodoRevisions) ?? []
        wellnessReminders = try container.decodeIfPresent([WellnessReminder].self, forKey: .wellnessReminders) ?? []
    }

    private static func migratedNotes(_ notes: [Note]) -> [Note] {
        notes.flatMap { note -> [Note] in
            guard note.wasDecodedWithoutRecordMode else {
                return [note]
            }

            if note.hasTextRecordContent && note.hasDrawingRecordContent {
                var textNote = note
                textNote.recordMode = .text
                textNote.drawingStrokes = []
                textNote.wasDecodedWithoutRecordMode = false

                var drawingNote = note
                drawingNote.id = UUID()
                drawingNote.recordMode = .drawing
                drawingNote.body = ""
                drawingNote.images = []
                drawingNote.wasDecodedWithoutRecordMode = false

                return [textNote, drawingNote]
            }

            var migratedNote = note
            migratedNote.recordMode = note.hasDrawingRecordContent ? .drawing : .text
            migratedNote.wasDecodedWithoutRecordMode = false
            return [migratedNote]
        }
    }
}
