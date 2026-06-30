import Foundation
import SwiftData

@ModelActor
actor SwiftDataTasksRepository: TasksRepository {
    func fetchAll() async throws -> [TodoTask] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func add(_ task: TodoTask) async throws {
        modelContext.insert(TaskEntity.make(from: task))
        try modelContext.save()
    }

    func toggleDone(id: UUID) async throws {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        entity.isDone.toggle()
        try modelContext.save()
    }
}
