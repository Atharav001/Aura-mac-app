import Foundation
import Observation

@Observable
final class TodoViewModel {
    var items: [TodoItem] = []
    var newItemTitle = ""
    var completedItemID: UUID?

    init() {
        items = DataStore.shared.todoItems
    }

    func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        items.append(item)
        save()
        newItemTitle = ""
    }

    func toggleItem(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
        if items[index].isCompleted {
            completedItemID = item.id
        }
        save()
    }

    func deleteItem(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearConfetti() {
        completedItemID = nil
    }

    private func save() {
        DataStore.shared.todoItems = items
        DataStore.shared.save()
    }
}
