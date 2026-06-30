import Foundation

@MainActor
final class InMemoryTasksRepository: TasksRepository {
    private var tasks: [TodoTask]

    init(seed: [TodoTask] = TodoTask.sampleList) {
        self.tasks = seed
    }

    func fetchAll() async throws -> [TodoTask] {
        tasks.sorted { $0.time < $1.time }
    }

    func add(_ task: TodoTask) async throws {
        tasks.append(task)
    }

    func toggleDone(id: UUID) async throws {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isDone.toggle()
    }
}
