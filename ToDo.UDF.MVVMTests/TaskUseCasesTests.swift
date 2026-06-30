import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
private final class StubTasksRepository: TasksRepository {
    var stored: [TodoTask]
    private(set) var addCalls: [TodoTask] = []
    private(set) var toggledIds: [UUID] = []

    init(stored: [TodoTask] = []) { self.stored = stored }

    func fetchAll() async throws -> [TodoTask] { stored }
    func add(_ task: TodoTask) async throws { addCalls.append(task); stored.append(task) }
    func toggleDone(id: UUID) async throws {
        toggledIds.append(id)
        if let i = stored.firstIndex(where: { $0.id == id }) { stored[i].isDone.toggle() }
    }
}

@MainActor
struct TaskUseCasesTests {
    @Test func fetchReturnsRepositoryContents() async throws {
        let repo = StubTasksRepository(stored: TodoTask.sampleList)
        let useCase = DefaultFetchTasksUseCase(repository: repo)
        let result = try await useCase()
        #expect(result.count == TodoTask.sampleList.count)
    }

    @Test func addInsertsTask() async throws {
        let repo = StubTasksRepository()
        let useCase = DefaultAddTaskUseCase(repository: repo)
        try await useCase(TodoTask(title: "Нова", time: "10:00", priority: .low))
        #expect(repo.addCalls.count == 1)
        #expect(repo.stored.count == 1)
    }

    @Test func addThrowsOnEmptyTitle() async {
        let repo = StubTasksRepository()
        let useCase = DefaultAddTaskUseCase(repository: repo)
        await #expect(throws: TaskValidationError.emptyTitle) {
            try await useCase(TodoTask(title: "   ", time: "10:00", priority: .low))
        }
        #expect(repo.addCalls.isEmpty)
    }

    @Test func toggleDelegatesToRepository() async throws {
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        let repo = StubTasksRepository(stored: [task])
        let useCase = DefaultToggleTaskUseCase(repository: repo)
        try await useCase(id: task.id)
        #expect(repo.toggledIds == [task.id])
        #expect(repo.stored[0].isDone)
    }
}
