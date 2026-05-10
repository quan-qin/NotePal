import Foundation

@MainActor
final class ReminderManager {
    private let todoStore: TodoStore
    private let onReminder: (String, [TodoItem]) -> Void
    private var deadlineTimer: Timer?
    private var safetyTimer: Timer?
    private var pendingChangeCheck: Task<Void, Never>?
    private var isChecking = false

    init(todoStore: TodoStore, onReminder: @escaping (String, [TodoItem]) -> Void) {
        self.todoStore = todoStore
        self.onReminder = onReminder
    }

    func start() {
        stop()
        todoStore.onTodosChanged = { [weak self] in
            self?.scheduleChangeCheck()
        }

        checkReminders()
        scheduleNextDeadlineCheck()

        // Backup only. Exact reminders are handled by `deadlineTimer`.
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
        todoStore.onTodosChanged = nil
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

        let dueTodos = todoStore.dueTodosNeedingReminder(asOf: date)
        guard !dueTodos.isEmpty else {
            return
        }

        if dueTodos.count == 1, let first = dueTodos.first {
            onReminder("待办到期：\(first.title)", dueTodos)
        } else {
            onReminder("\(dueTodos.count) 个待办已到期。", dueTodos)
        }

        scheduleNextDeadlineCheck(asOf: Date())
    }

    private func scheduleNextDeadlineCheck(asOf date: Date = Date()) {
        deadlineTimer?.invalidate()
        deadlineTimer = nil

        let nextDueDate = todoStore.todos
            .filter { todo in
                guard let dueDate = todo.dueDate else {
                    return false
                }

                return !todo.isCompleted
                    && dueDate > date
                    && !todoStore.remindedTodoRevisions.contains(todo.reminderRevisionKey)
            }
            .compactMap(\.dueDate)
            .min()

        guard let nextDueDate else {
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
