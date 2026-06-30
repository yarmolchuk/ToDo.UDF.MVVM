import Foundation
import SwiftData

@MainActor
enum AppComposition {
    static func bootstrap() -> ModelContainer {
        do {
            let container = try DataAssembly.makeModelContainer()
            DataAssembly.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Не вдалося ініціалізувати сховище задач: \(error)")
        }
    }

    static func tasksUseCases(container: ModelContainer) -> TasksUseCases {
        DataAssembly.makeUseCases(repository: SwiftDataTasksRepository(modelContainer: container))
    }
}
