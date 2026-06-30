import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    private func makeCoordinator(seed: [TodoTask] = TodoTask.sampleList) -> TaskFlowCoordinator {
        let router = Router()
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed))
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        return TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in })
    }

    @Test func createTaskRequestedPushesNewTask() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)
    }

    @Test func saveRequestedPushesCreated() {
        let c = makeCoordinator()
        c.handle(.saveRequested(.sample))
        #expect(c.router.path.count == 1)
    }

    @Test func dismissFormPops() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)
        c.handle(.dismissForm)
        #expect(c.router.path.isEmpty)
    }

    @Test func finishCreatedPopsToRoot() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        c.handle(.saveRequested(.sample))
        #expect(c.router.path.count == 2)
        c.handle(.finishCreated)
        #expect(c.router.path.isEmpty)
    }

    @Test func listViewModelIsRetainedStableInstance() {
        let c = makeCoordinator()
        #expect(c.listViewModel === c.listViewModel)
    }

    @Test func makesNewTaskViewModel() {
        let c = makeCoordinator()
        #expect(c.makeNewTaskViewModel().props.canSave)
    }

    @Test func makesTaskCreatedViewModelCarryingTask() {
        let c = makeCoordinator()
        #expect(c.makeTaskCreatedViewModel(task: .sample).props.task == .sample)
    }
}
