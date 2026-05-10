import Foundation

// Access to mutable persistence state is serialized through `queue`.
final class LocalDataStore: @unchecked Sendable {
    static let shared = LocalDataStore()

    let dataURL: URL

    private let legacyDataURLs: [URL]
    private let queue = DispatchQueue(label: "app.notepal.local-data")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser

        self.dataURL = applicationSupport
            .appendingPathComponent("NotePal", isDirectory: true)
            .appendingPathComponent("notepal-data.json", isDirectory: false)
        self.legacyDataURLs = [
            applicationSupport
                .appendingPathComponent("NotePet", isDirectory: true)
                .appendingPathComponent("notepet-data.json", isDirectory: false),
            applicationSupport
                .appendingPathComponent(Self.joined("NotePet-", "a", "t", "h"), isDirectory: true)
                .appendingPathComponent("notepet-data.json", isDirectory: false),
            applicationSupport
                .appendingPathComponent("NotePet4xyz", isDirectory: true)
                .appendingPathComponent("notepet4xyz-data.json", isDirectory: false),
            applicationSupport
                .appendingPathComponent(Self.joined("NotePet-", "z", "y", "z", "x"), isDirectory: true)
                .appendingPathComponent(Self.joined("notepet-", "z", "y", "z", "x", "-data.json"), isDirectory: false)
        ]

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> NotePalData {
        try queue.sync {
            try loadUnlocked()
        }
    }

    @discardableResult
    func update(_ mutation: (inout NotePalData) -> Void) throws -> NotePalData {
        try queue.sync {
            var data = try loadUnlocked()
            mutation(&data)
            try saveUnlocked(data)
            return data
        }
    }

    private func loadUnlocked() throws -> NotePalData {
        if fileManager.fileExists(atPath: dataURL.path) {
            return try loadData(from: dataURL)
        }

        if let migratedData = try loadMigratedLegacyData() {
            try saveUnlocked(migratedData)
            return migratedData
        }

        return NotePalData()
    }

    private func loadData(from url: URL) throws -> NotePalData {
        let rawData = try Data(contentsOf: url)
        guard !rawData.isEmpty else {
            return NotePalData()
        }

        return try decoder.decode(NotePalData.self, from: rawData)
    }

    private func saveUnlocked(_ data: NotePalData) throws {
        let directory = dataURL.deletingLastPathComponent()

        // Local persistence is intentionally one readable JSON file so users can
        // inspect, back up, or repair their notes without a database tool.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoded = try encoder.encode(data)
        try encoded.write(to: dataURL, options: [.atomic])
    }

    private func loadMigratedLegacyData() throws -> NotePalData? {
        var migratedData = NotePalData()
        var didLoadLegacyData = false

        for legacyURL in legacyDataURLs where fileManager.fileExists(atPath: legacyURL.path) {
            let legacyData = try loadData(from: legacyURL)
            merge(legacyData, into: &migratedData)
            didLoadLegacyData = true
        }

        guard didLoadLegacyData else {
            return nil
        }

        if migratedData.wellnessReminders.isEmpty {
            migratedData.wellnessReminders = WellnessReminder.defaults()
        } else {
            mergeMissingDefaultWellnessReminders(into: &migratedData)
        }

        return migratedData
    }

    private func merge(_ incoming: NotePalData, into data: inout NotePalData) {
        data.notes = mergeNotes(data.notes, incoming.notes)
        data.todos = mergeTodos(data.todos, incoming.todos)
        data.remindedTodoRevisions.formUnion(incoming.remindedTodoRevisions)
        data.wellnessReminders = mergeWellnessReminders(data.wellnessReminders, incoming.wellnessReminders)
    }

    private func mergeNotes(_ current: [Note], _ incoming: [Note]) -> [Note] {
        var itemsByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for note in incoming {
            if
                let existing = itemsByID[note.id],
                existing.updatedAt >= note.updatedAt
            {
                continue
            }

            itemsByID[note.id] = note
        }

        return Array(itemsByID.values)
    }

    private func mergeTodos(_ current: [TodoItem], _ incoming: [TodoItem]) -> [TodoItem] {
        var itemsByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for todo in incoming {
            if
                let existing = itemsByID[todo.id],
                existing.updatedAt >= todo.updatedAt
            {
                continue
            }

            itemsByID[todo.id] = todo
        }

        return Array(itemsByID.values)
    }

    private func mergeWellnessReminders(
        _ current: [WellnessReminder],
        _ incoming: [WellnessReminder]
    ) -> [WellnessReminder] {
        var remindersByKind = Dictionary(uniqueKeysWithValues: current.map { ($0.kind, $0) })

        for reminder in incoming {
            if
                let existing = remindersByKind[reminder.kind],
                existing.updatedAt >= reminder.updatedAt
            {
                continue
            }

            remindersByKind[reminder.kind] = reminder
        }

        return WellnessReminder.Kind.allCases.compactMap { remindersByKind[$0] }
    }

    private func mergeMissingDefaultWellnessReminders(into data: inout NotePalData) {
        var remindersByKind = Dictionary(uniqueKeysWithValues: data.wellnessReminders.map { ($0.kind, $0) })

        for reminder in WellnessReminder.defaults() where remindersByKind[reminder.kind] == nil {
            remindersByKind[reminder.kind] = reminder
        }

        data.wellnessReminders = WellnessReminder.Kind.allCases.compactMap { remindersByKind[$0] }
    }

    private static func joined(_ parts: String...) -> String {
        parts.joined()
    }
}
