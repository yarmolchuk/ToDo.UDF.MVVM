import Foundation

protocol TasksRepository: Sendable {
    func fetchAll() async throws -> [TodoTask]
    func add(_ task: TodoTask) async throws
    func toggleDone(id: UUID) async throws
}
