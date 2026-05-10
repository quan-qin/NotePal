import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var wellnessReminderStore: WellnessReminderStore
    @ObservedObject var panelState: PanelState

    var body: some View {
        ZStack(alignment: .topLeading) {
            panelContent
                .offset(x: panelState.attachmentSide == .left ? 18 : 0)

            PanelPopoverTail(side: panelState.attachmentSide)
                .fill(panelFill)
                .overlay(
                    PanelPopoverTail(side: panelState.attachmentSide)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
                )
                .frame(width: 18, height: 30)
                .position(
                    x: panelState.attachmentSide == .left ? 9 : 399,
                    y: panelState.tailCenterY
                )
        }
        .frame(width: 414, height: 520)
        .background(Color.clear)
    }

    private var panelContent: some View {
        VStack(spacing: 12) {
            header

            Picker("", selection: $panelState.selectedTab) {
                ForEach(PanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            errorText

            Group {
                switch panelState.selectedTab {
                case .notes:
                    notesList
                case .todos:
                    TodoListView(
                        todoStore: todoStore
                    )
                case .wellness:
                    wellnessSettings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        .frame(width: 390, height: 520)
        .background(panelBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NotePal")
                    .font(.system(size: 17, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if panelState.selectedTab != .wellness {
                Button(action: addCurrentItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                .help(panelState.selectedTab == .notes ? "新建笔记" : "新建待办")
            }
        }
    }

    private var subtitle: String {
        switch panelState.selectedTab {
        case .notes:
            return "快速笔记"
        case .todos:
            return "待办事项"
        case .wellness:
            return "养生提醒"
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = noteStore.lastError ?? todoStore.lastError ?? wellnessReminderStore.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if noteStore.notes.isEmpty {
                    emptyState("还没有笔记。")
                } else {
                    ForEach(noteStore.notes) { note in
                        NoteCard(note: note, noteStore: noteStore)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var wellnessSettings: some View {
        ScrollView {
            WellnessReminderSection(wellnessReminderStore: wellnessReminderStore)
                .padding(.vertical, 2)
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
    }

    private var panelFill: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.96)
    }

    private func addCurrentItem() {
        switch panelState.selectedTab {
        case .notes:
            _ = noteStore.createNote()
        case .todos:
            _ = todoStore.createTodo()
        case .wellness:
            break
        }
    }
}

private struct PanelPopoverTail: Shape {
    let side: PanelAttachmentSide

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch side {
        case .left:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.midY + 2)
            )
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.midY + 2)
            )
        }

        path.closeSubpath()
        return path
    }
}

private struct NoteCard: View {
    let note: Note
    @ObservedObject var noteStore: NoteStore

    @State private var title: String
    @State private var bodyText: String

    init(note: Note, noteStore: NoteStore) {
        self.note = note
        self.noteStore = noteStore
        _title = State(initialValue: note.title)
        _bodyText = State(initialValue: note.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                TextField("标题", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))

                Button {
                    noteStore.deleteNote(id: note.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除笔记")
            }

            TextEditor(text: $bodyText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72)

            HStack {
                Text("创建于 \(DateFormatter.notePalShortDateTime.string(from: note.createdAt))")
                Spacer()
                Text("更新于 \(DateFormatter.notePalShortDateTime.string(from: note.updatedAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(cardBackground)
        .onChange(of: title) { _ in
            save()
        }
        .onChange(of: bodyText) { _ in
            save()
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
        var updated = note
        updated.title = title
        updated.body = bodyText
        noteStore.updateNote(updated)
    }
}
