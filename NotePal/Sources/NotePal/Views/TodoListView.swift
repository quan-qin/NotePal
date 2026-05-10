import SwiftUI

enum TodoFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case active = "进行中"
    case completed = "已完成"
    case dueToday = "今日到期"

    var id: String {
        rawValue
    }
}

struct TodoListView: View {
    @ObservedObject var todoStore: TodoStore
    @State private var filter: TodoFilter = .all

    var body: some View {
        VStack(spacing: 10) {
            Picker("", selection: $filter) {
                ForEach(TodoFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if filteredTodos.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredTodos) { todo in
                            TodoRow(todo: todo, todoStore: todoStore)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filteredTodos: [TodoItem] {
        let calendar = Calendar.current

        return todoStore.todos.filter { todo in
            guard !todo.isWellnessTodo else {
                return false
            }

            switch filter {
            case .all:
                return true
            case .active:
                return !todo.isCompleted
            case .completed:
                return todo.isCompleted
            case .dueToday:
                guard let dueDate = todo.dueDate else {
                    return false
                }

                return !todo.isCompleted && calendar.isDateInToday(dueDate)
            }
        }
    }

    private var emptyState: some View {
        Text("这里还没有待办。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 230)
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    @ObservedObject var todoStore: TodoStore

    @State private var title: String
    @State private var descriptionText: String
    @State private var isCompleted: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(todo: TodoItem, todoStore: TodoStore) {
        self.todo = todo
        self.todoStore = todoStore
        _title = State(initialValue: todo.title)
        _descriptionText = State(initialValue: todo.description ?? "")
        _isCompleted = State(initialValue: todo.isCompleted)
        _hasDueDate = State(initialValue: todo.dueDate != nil)
        _dueDate = State(initialValue: todo.dueDate ?? Date().addingTimeInterval(3600))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Toggle("", isOn: $isCompleted)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help(isCompleted ? "标记为未完成" : "标记为已完成")

                VStack(alignment: .leading, spacing: 6) {
                    TextField("待办标题", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .strikethrough(isCompleted)

                    TextField("描述", text: $descriptionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(2...4)
                        .foregroundStyle(.secondary)
                }
                .opacity(isCompleted ? 0.58 : 1)

                Button {
                    todoStore.deleteTodo(id: todo.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除待办")
            }

            Divider()

            deadlineControls

            HStack {
                Text("创建于 \(DateFormatter.notePalShortDateTime.string(from: todo.createdAt))")
                Spacer()
                Text("更新于 \(DateFormatter.notePalShortDateTime.string(from: todo.updatedAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let dueDate = todo.dueDate {
                HStack {
                    Text(dueDate <= Date() && !todo.isCompleted ? "已到期" : "截止 \(DateFormatter.notePalShortDateTime.string(from: dueDate))")
                        .foregroundStyle(dueDate <= Date() && !todo.isCompleted ? .red : .secondary)
                    Spacer()
                }
                .font(.caption2)
            }
        }
        .padding(10)
        .background(cardBackground)
        .onChange(of: title) { _ in save() }
        .onChange(of: descriptionText) { _ in save() }
        .onChange(of: isCompleted) { _ in save() }
        .onChange(of: hasDueDate) { _ in save() }
        .onChange(of: dueDate) { _ in save() }
    }

    private var deadlineControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("截止时间", isOn: $hasDueDate)
                .font(.caption)

            if hasDueDate {
                DatePicker(
                    "",
                    selection: $dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private func save() {
        var updated = todo
        updated.title = title
        updated.description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText
        updated.isCompleted = isCompleted
        updated.dueDate = hasDueDate ? normalizedDueDate(dueDate) : nil
        todoStore.updateTodo(updated)
    }

    private func normalizedDueDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        return calendar.date(from: components) ?? date
    }
}
