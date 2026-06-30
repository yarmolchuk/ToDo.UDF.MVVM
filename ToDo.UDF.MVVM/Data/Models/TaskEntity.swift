import Foundation
import SwiftData

@Model
final class TaskEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var time: String
    var priorityRaw: String
    var isDone: Bool

    init(id: UUID, title: String, notes: String?, time: String, priorityRaw: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.notes = notes
        self.time = time
        self.priorityRaw = priorityRaw
        self.isDone = isDone
    }
}

extension TaskEntity {
    func toDomain() -> TodoTask {
        TodoTask(
            id: id,
            title: title,
            notes: notes,
            time: time,
            priority: TaskPriority(rawValue: priorityRaw) ?? .medium,
            isDone: isDone
        )
    }

    static func make(from task: TodoTask) -> TaskEntity {
        TaskEntity(
            id: task.id,
            title: task.title,
            notes: task.notes,
            time: task.time,
            priorityRaw: task.priority.rawValue,
            isDone: task.isDone
        )
    }
}
