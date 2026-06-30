import Foundation

struct TodoTask: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var time: String
    var priority: TaskPriority
    var isDone: Bool

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        time: String,
        priority: TaskPriority,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.time = time
        self.priority = priority
        self.isDone = isDone
    }
}

extension TodoTask {
    static let sampleList: [TodoTask] = [
        TodoTask(title: "Підготувати презентацію", time: "09:30", priority: .high),
        TodoTask(
            title: "Дзвінок з командою дизайну",
            notes: "Обговорити нову сітку інтерфейсу",
            time: "11:00",
            priority: .medium
        ),
        TodoTask(title: "Рев'ю пул-реквестів", time: "14:00", priority: .low),
        TodoTask(title: "Запланувати спринт", time: "16:30", priority: .medium),
        TodoTask(title: "Оновити залежності", time: "08:00", priority: .low, isDone: true),
        TodoTask(title: "Розгорнути на стейджинг", time: "18:00", priority: .high, isDone: true),
    ]
}
