//
//  DataAssembly.swift
//  ToDo.UDF.MVVM
//
//  Збірка шару даних: контейнер SwiftData, сидування, набір use cases.
//

import Foundation
import SwiftData

@MainActor
enum DataAssembly {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskEntity.self])
        // Окреме сховище "Tasks.store", щоб не конфліктувати зі стандартним
        // сховищем шаблонного Item, поки воно співіснує (#4). #5 спростить.
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: URL.documentsDirectory.appending(path: "Tasks.store"))
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<TaskEntity>())) ?? 0
        guard existing == 0 else { return }
        for task in TodoTask.sampleList {
            context.insert(TaskEntity.make(from: task))
        }
        try? context.save()
    }

    static func makeUseCases(repository: any TasksRepository) -> TasksUseCases {
        TasksUseCases(
            fetchTasks: DefaultFetchTasksUseCase(repository: repository),
            addTask: DefaultAddTaskUseCase(repository: repository),
            toggleTask: DefaultToggleTaskUseCase(repository: repository)
        )
    }

    static func makeLiveUseCases() -> TasksUseCases {
        do {
            let container = try makeModelContainer()
            seedIfNeeded(context: container.mainContext)
            return makeUseCases(repository: SwiftDataTasksRepository(container: container))
        } catch {
            fatalError("Не вдалося ініціалізувати сховище задач: \(error)")
        }
    }
}
