import Testing
import Foundation
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct SwiftDataTasksRepositoryTests {
    private func makeRepository() throws -> SwiftDataTasksRepository {
        let container = try ModelContainer(
            for: TaskEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataTasksRepository(container: container)
    }

    @Test func addThenFetchRoundTrips() async throws {
        let repo = try makeRepository()
        let task = TodoTask(title: "Зустріч", notes: "деталі", time: "09:30", priority: .high)
        try await repo.add(task)
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0] == task)
    }

    @Test func fetchSortsByTimeAscending() async throws {
        let repo = try makeRepository()
        try await repo.add(TodoTask(title: "Пізніше", time: "18:00", priority: .low))
        try await repo.add(TodoTask(title: "Раніше", time: "08:00", priority: .low))
        let all = try await repo.fetchAll()
        #expect(all.map(\.time) == ["08:00", "18:00"])
    }

    @Test func toggleDoneFlipsAndPersists() async throws {
        let repo = try makeRepository()
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        try await repo.add(task)
        try await repo.toggleDone(id: task.id)
        let all = try await repo.fetchAll()
        #expect(all[0].isDone)
    }
}
