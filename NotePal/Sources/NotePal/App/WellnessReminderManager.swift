import Foundation

@MainActor
final class WellnessReminderManager {
    private let wellnessReminderStore: WellnessReminderStore
    private let onReminder: (String, [WellnessReminder]) -> Void
    private var deadlineTimer: Timer?
    private var safetyTimer: Timer?
    private var pendingChangeCheck: Task<Void, Never>?
    private var isChecking = false

    init(
        wellnessReminderStore: WellnessReminderStore,
        onReminder: @escaping (String, [WellnessReminder]) -> Void
    ) {
        self.wellnessReminderStore = wellnessReminderStore
        self.onReminder = onReminder
    }

    func start() {
        stop()
        wellnessReminderStore.onRemindersChanged = { [weak self] in
            self?.scheduleChangeCheck()
        }

        checkReminders()
        scheduleNextDeadlineCheck()

        let safetyTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkReminders()
            }
        }
        safetyTimer.tolerance = 5
        RunLoop.main.add(safetyTimer, forMode: .common)
        self.safetyTimer = safetyTimer
    }

    func stop() {
        wellnessReminderStore.onRemindersChanged = nil
        pendingChangeCheck?.cancel()
        pendingChangeCheck = nil
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        safetyTimer?.invalidate()
        safetyTimer = nil
    }

    private func scheduleChangeCheck() {
        pendingChangeCheck?.cancel()
        pendingChangeCheck = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else {
                return
            }

            self?.checkReminders()
            self?.scheduleNextDeadlineCheck()
        }
    }

    func checkReminders(asOf date: Date = Date()) {
        guard !isChecking else {
            return
        }

        isChecking = true
        defer {
            isChecking = false
        }

        let dueReminders = wellnessReminderStore.dueReminders(asOf: date)
        guard !dueReminders.isEmpty else {
            scheduleNextDeadlineCheck(asOf: date)
            return
        }

        if dueReminders.count == 1, let first = dueReminders.first {
            onReminder(first.message, dueReminders)
        } else {
            onReminder("\(dueReminders.count) 个养生提醒到了。", dueReminders)
        }

        wellnessReminderStore.advanceReminders(dueReminders, from: Date())
        scheduleNextDeadlineCheck(asOf: Date())
    }

    private func scheduleNextDeadlineCheck(asOf date: Date = Date()) {
        deadlineTimer?.invalidate()
        deadlineTimer = nil

        guard let nextDueDate = wellnessReminderStore.nextDueDate(asOf: date) else {
            return
        }

        let interval = max(0.05, nextDueDate.timeIntervalSince(date))
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkReminders(asOf: Date())
                self?.scheduleNextDeadlineCheck()
            }
        }
        timer.tolerance = 0
        RunLoop.main.add(timer, forMode: .common)
        deadlineTimer = timer
    }
}
