import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var lastError: String?

    var onError: ((String) -> Void)?

    private let storage: LocalDataStore

    init(storage: LocalDataStore = .shared) {
        self.storage = storage
        reload()
    }

    func reload() {
        do {
            notes = sort(try storage.load().notes)
            lastError = nil
        } catch {
            lastError = "无法加载笔记：\(error.localizedDescription)"
            onError?(lastError ?? "无法加载笔记。")
        }
    }

    @discardableResult
    func createNote(title: String = "未命名笔记", body: String = "") -> Note {
        let note = Note(title: title, body: body)

        persist { data in
            data.notes.insert(note, at: 0)
        }

        return note
    }

    func updateNote(_ note: Note) {
        var updated = note
        updated.updatedAt = Date()

        persist { data in
            guard let index = data.notes.firstIndex(where: { $0.id == updated.id }) else {
                return
            }

            data.notes[index] = updated
        }
    }

    func deleteNote(id: UUID) {
        persist { data in
            data.notes.removeAll { $0.id == id }
        }
    }

    private func persist(_ mutation: (inout NotePalData) -> Void) {
        do {
            let data = try storage.update(mutation)
            notes = sort(data.notes)
            lastError = nil
        } catch {
            lastError = "无法保存笔记：\(error.localizedDescription)"
            onError?(lastError ?? "无法保存笔记。")
        }
    }

    private func sort(_ notes: [Note]) -> [Note] {
        notes.sorted { first, second in
            first.updatedAt > second.updatedAt
        }
    }
}
