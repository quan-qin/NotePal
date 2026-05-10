import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var remindedTodoRevisions: Set<String> = []
    @Published var lastError: String?

    var onTodosChanged: (() -> Void)?
    var onTodoCompleted: ((TodoItem) -> Void)?
    var onError: ((String) -> Void)?

    var incompleteCount: Int {
        todos.filter { !$0.isCompleted && !$0.isWellnessTodo }.count
    }

    private let storage: LocalDataStore

    init(storage: LocalDataStore = .shared) {
        self.storage = storage
        reload()
    }

    func reload() {
        do {
            let data = try storage.update { data in
                data.todos.removeAll { $0.isWellnessTodo }
                cleanReminderState(in: &data)
            }
            todos = sort(data.todos.filter { !$0.isWellnessTodo })
            remindedTodoRevisions = data.remindedTodoRevisions
            lastError = nil
            onTodosChanged?()
        } catch {
            lastError = "无法加载待办：\(error.localizedDescription)"
            onError?(lastError ?? "无法加载待办。")
        }
    }

    @discardableResult
    func createTodo(
        title: String = "新待办",
        description: String? = nil,
        dueDate: Date? = nil
    ) -> TodoItem {
        let todo = TodoItem(title: title, description: description, dueDate: dueDate)

        persist { data in
            data.todos.insert(todo, at: 0)
            cleanReminderState(in: &data)
        }

        return todo
    }

    func updateTodo(_ todo: TodoItem) {
        var updated = todo
        updated.updatedAt = Date()
        let completedTodo = todos.first(where: { $0.id == updated.id && !$0.isCompleted && updated.isCompleted })

        persist { data in
            guard let index = data.todos.firstIndex(where: { $0.id == updated.id }) else {
                return
            }

            data.todos[index] = updated
            cleanReminderState(in: &data)
        }

        if completedTodo != nil {
            onTodoCompleted?(updated)
        }
    }

    func toggleCompleted(id: UUID) {
        var completedTodo: TodoItem?

        persist { data in
            guard let index = data.todos.firstIndex(where: { $0.id == id }) else {
                return
            }

            data.todos[index].isCompleted.toggle()
            data.todos[index].updatedAt = Date()
            if data.todos[index].isCompleted {
                completedTodo = data.todos[index]
            }
            cleanReminderState(in: &data)
        }

        if let completedTodo {
            onTodoCompleted?(completedTodo)
        }
    }

    func deleteTodo(id: UUID) {
        persist { data in
            data.todos.removeAll { $0.id == id }
            cleanReminderState(in: &data)
        }
    }

    func dueTodosNeedingReminder(asOf date: Date = Date()) -> [TodoItem] {
        todos.filter { todo in
            !todo.isWellnessTodo
                && todo.isDue(asOf: date)
                && !remindedTodoRevisions.contains(todo.reminderRevisionKey)
        }
    }

    func markReminded(_ dueTodos: [TodoItem]) {
        guard !dueTodos.isEmpty else {
            return
        }

        let keys = Set(dueTodos.filter { !$0.isWellnessTodo }.map(\.reminderRevisionKey))

        persist { data in
            if !keys.isEmpty {
                data.remindedTodoRevisions.formUnion(keys)
            }

            cleanReminderState(in: &data)
        }
    }

    private func persist(_ mutation: (inout NotePalData) -> Void) {
        do {
            let data = try storage.update(mutation)
            todos = sort(data.todos.filter { !$0.isWellnessTodo })
            remindedTodoRevisions = data.remindedTodoRevisions
            lastError = nil
            onTodosChanged?()
        } catch {
            lastError = "无法保存待办：\(error.localizedDescription)"
            onError?(lastError ?? "无法保存待办。")
        }
    }

    private func sort(_ todos: [TodoItem]) -> [TodoItem] {
        todos.sorted { first, second in
            switch (first.dueDate, second.dueDate) {
            case let (firstDate?, secondDate?):
                return firstDate < secondDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return first.updatedAt > second.updatedAt
            }
        }
    }
}

private func cleanReminderState(in data: inout NotePalData) {
    let currentKeys = Set(data.todos.filter { !$0.isWellnessTodo }.map(\.reminderRevisionKey))
    data.remindedTodoRevisions = data.remindedTodoRevisions.intersection(currentKeys)
}
