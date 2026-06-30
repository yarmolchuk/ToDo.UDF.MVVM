import Foundation
import SwiftData

@MainActor
enum DataAssembly {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
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

}
