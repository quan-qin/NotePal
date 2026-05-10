import Foundation

@MainActor
final class WellnessReminderStore: ObservableObject {
    @Published private(set) var reminders: [WellnessReminder] = []
    @Published var lastError: String?

    var onRemindersChanged: (() -> Void)?
    var onError: ((String) -> Void)?

    private let storage: LocalDataStore

    init(storage: LocalDataStore = .shared) {
        self.storage = storage
        reload()
    }

    func reload() {
        do {
            let data = try storage.update { data in
                normalizeWellnessData(in: &data)
            }
            reminders = sort(data.wellnessReminders)
            lastError = nil
            onRemindersChanged?()
        } catch {
            lastError = "无法加载养生提醒：\(error.localizedDescription)"
            onError?(lastError ?? "无法加载养生提醒。")
        }
    }

    func setEnabled(kind: WellnessReminder.Kind, isEnabled: Bool) {
        persist { data in
            normalizeWellnessData(in: &data)
            guard let index = data.wellnessReminders.firstIndex(where: { $0.kind == kind }) else {
                return
            }

            data.wellnessReminders[index].isEnabled = isEnabled
            data.wellnessReminders[index].updatedAt = Date()
            if isEnabled {
                let interval = TimeInterval(data.wellnessReminders[index].effectiveIntervalMinutes * 60)
                data.wellnessReminders[index].nextReminderAt = Date().addingTimeInterval(interval)
            }
        }
    }

    func setInterval(kind: WellnessReminder.Kind, minutes: Int) {
        persist { data in
            normalizeWellnessData(in: &data)
            guard let index = data.wellnessReminders.firstIndex(where: { $0.kind == kind }) else {
                return
            }

            let normalizedMinutes = min(max(minutes, 5), 1440)
            data.wellnessReminders[index].intervalMinutes = normalizedMinutes
            data.wellnessReminders[index].nextReminderAt = Date().addingTimeInterval(TimeInterval(normalizedMinutes * 60))
            data.wellnessReminders[index].updatedAt = Date()
        }
    }

    func dueReminders(asOf date: Date = Date()) -> [WellnessReminder] {
        reminders.filter { reminder in
            reminder.isEnabled && reminder.nextReminderAt <= date
        }
    }

    func nextDueDate(asOf date: Date = Date()) -> Date? {
        reminders
            .filter { $0.isEnabled && $0.nextReminderAt > date }
            .map(\.nextReminderAt)
            .min()
    }

    func advanceReminders(_ dueReminders: [WellnessReminder], from date: Date = Date()) {
        guard !dueReminders.isEmpty else {
            return
        }

        let dueKinds = Set(dueReminders.map(\.kind))
        persist { data in
            normalizeWellnessData(in: &data)
            for index in data.wellnessReminders.indices where dueKinds.contains(data.wellnessReminders[index].kind) {
                let interval = TimeInterval(data.wellnessReminders[index].effectiveIntervalMinutes * 60)
                data.wellnessReminders[index].nextReminderAt = date.addingTimeInterval(interval)
                data.wellnessReminders[index].updatedAt = date
            }
        }
    }

    private func persist(_ mutation: (inout NotePalData) -> Void) {
        do {
            let data = try storage.update(mutation)
            reminders = sort(data.wellnessReminders)
            lastError = nil
            onRemindersChanged?()
        } catch {
            lastError = "无法保存养生提醒：\(error.localizedDescription)"
            onError?(lastError ?? "无法保存养生提醒。")
        }
    }

    private func sort(_ reminders: [WellnessReminder]) -> [WellnessReminder] {
        let order = Dictionary(uniqueKeysWithValues: WellnessReminder.Kind.allCases.enumerated().map { ($1, $0) })
        return reminders.sorted { first, second in
            (order[first.kind] ?? 0) < (order[second.kind] ?? 0)
        }
    }
}

private func normalizeWellnessData(in data: inout NotePalData) {
    let now = Date()
    var remindersByKind = Dictionary(uniqueKeysWithValues: WellnessReminder.defaults(now: now).map { ($0.kind, $0) })

    for reminder in data.wellnessReminders {
        var normalized = reminder
        normalized.intervalMinutes = normalized.effectiveIntervalMinutes
        remindersByKind[normalized.kind] = normalized
    }

    // One-time migration from the earlier MVP, where wellness reminders were
    // represented as ordinary todos. They are now independent timed reminders.
    for legacyTodo in data.todos where legacyTodo.isWellnessTodo {
        guard
            let rawKind = legacyTodo.wellnessKind,
            let kind = WellnessReminder.Kind(rawValue: rawKind)
        else {
            continue
        }

        let intervalMinutes = legacyTodo.effectiveWellnessIntervalMinutes
        remindersByKind[kind] = WellnessReminder(
            kind: kind,
            isEnabled: !legacyTodo.isCompleted,
            intervalMinutes: intervalMinutes,
            nextReminderAt: legacyTodo.dueDate ?? now.addingTimeInterval(TimeInterval(intervalMinutes * 60)),
            updatedAt: legacyTodo.updatedAt
        )
    }

    data.todos.removeAll { $0.isWellnessTodo }
    data.wellnessReminders = WellnessReminder.Kind.allCases.compactMap { remindersByKind[$0] }

    let currentTodoReminderKeys = Set(data.todos.map(\.reminderRevisionKey))
    data.remindedTodoRevisions = data.remindedTodoRevisions.intersection(currentTodoReminderKeys)
}
