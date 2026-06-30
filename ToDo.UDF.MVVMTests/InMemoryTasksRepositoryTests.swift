import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct InMemoryTasksRepositoryTests {
    @Test func fetchAllReturnsSeedSortedByTime() async throws {
        let repo = InMemoryTasksRepository(seed: [
            TodoTask(title: "Пізніше", time: "18:00", priority: .low),
            TodoTask(title: "Раніше", time: "08:00", priority: .low),
        ])
        let all = try await repo.fetchAll()
        #expect(all.map(\.time) == ["08:00", "18:00"])
    }

    @Test func addAppends() async throws {
        let repo = InMemoryTasksRepository(seed: [])
        try await repo.add(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await repo.fetchAll().count == 1)
    }

    @Test func toggleDoneFlips() async throws {
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        let repo = InMemoryTasksRepository(seed: [task])
        try await repo.toggleDone(id: task.id)
        #expect(try await repo.fetchAll()[0].isDone)
    }
}
