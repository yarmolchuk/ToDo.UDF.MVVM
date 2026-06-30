import Testing
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct AppCompositionTests {
    @Test func tasksUseCasesBuildsWorkingBundle() async throws {
        let container = try DataAssembly.makeModelContainer(inMemory: true)
        let useCases = AppComposition.tasksUseCases(container: container)
        try await useCases.addTask(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await useCases.fetchTasks().count == 1)
    }
}
