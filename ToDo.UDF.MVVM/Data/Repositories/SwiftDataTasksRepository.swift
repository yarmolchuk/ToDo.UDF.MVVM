//
//  SwiftDataTasksRepository.swift
//  ToDo.UDF.MVVM
//
//  Реалізація TasksRepository на SwiftData. Володіє контейнером,
//  працює з його головним контекстом.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTasksRepository: TasksRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [TodoTask] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )
        return try container.mainContext.fetch(descriptor).map { $0.toDomain() }
    }

    func add(_ task: TodoTask) async throws {
        container.mainContext.insert(TaskEntity.make(from: task))
        try container.mainContext.save()
    }

    func toggleDone(id: UUID) async throws {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try container.mainContext.fetch(descriptor).first else { return }
        entity.isDone.toggle()
        try container.mainContext.save()
    }
}
