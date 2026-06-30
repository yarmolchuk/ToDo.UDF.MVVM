import Testing
import Foundation
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct DataAssemblyTests {
    @Test func seedIfNeededSeedsOnceIntoEmptyStore() throws {
        let container = try DataAssembly.makeModelContainer(inMemory: true)
        DataAssembly.seedIfNeeded(context: container.mainContext)
        let afterFirst = try container.mainContext.fetchCount(FetchDescriptor<TaskEntity>())
        #expect(afterFirst == TodoTask.sampleList.count)
        DataAssembly.seedIfNeeded(context: container.mainContext)
        let afterSecond = try container.mainContext.fetchCount(FetchDescriptor<TaskEntity>())
        #expect(afterSecond == TodoTask.sampleList.count)
    }

    @Test func makeUseCasesBuildsWorkingBundle() async throws {
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: []))
        try await useCases.addTask(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await useCases.fetchTasks().count == 1)
    }
}
