import Foundation

enum TaskValidationError: Error, Equatable {
    case emptyTitle
}

protocol FetchTasksUseCase: Sendable {
    func callAsFunction() async throws -> [TodoTask]
}

protocol AddTaskUseCase: Sendable {
    func callAsFunction(_ task: TodoTask) async throws
}

protocol ToggleTaskUseCase: Sendable {
    func callAsFunction(id: UUID) async throws
}

struct DefaultFetchTasksUseCase: FetchTasksUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction() async throws -> [TodoTask] {
        try await repository.fetchAll()
    }
}

struct DefaultAddTaskUseCase: AddTaskUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction(_ task: TodoTask) async throws {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskValidationError.emptyTitle
        }
        try await repository.add(task)
    }
}

struct DefaultToggleTaskUseCase: ToggleTaskUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction(id: UUID) async throws {
        try await repository.toggleDone(id: id)
    }
}
