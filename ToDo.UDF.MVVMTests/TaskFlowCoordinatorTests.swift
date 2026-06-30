import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    private func makeCoordinator() -> TaskFlowCoordinator {
        let useCases = DataAssembly.makeUseCases(
            repository: InMemoryTasksRepository(seed: TodoTask.sampleList)
        )
        return TaskFlowCoordinator(factory: DefaultUIFactory(useCases: useCases))
    }

    @Test func finishCreatedPopsToRoot() {
        let coordinator = makeCoordinator()
        coordinator.router.push("x")
        #expect(coordinator.router.path.count == 1)
        coordinator.handle(.finishCreated)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesViewModelCarryingTask() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeTaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }

    @Test func createTaskRequestedIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.createTaskRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesTaskListViewModelWithEmptyInitialProps() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeTaskListViewModel()
        #expect(vm.props.active.isEmpty)
        #expect(vm.props.completed.isEmpty)
    }

    @Test func saveRequestedIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.saveRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func dismissFormIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.dismissForm)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesNewTaskViewModel() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeNewTaskViewModel()
        #expect(vm.props.canSave)
    }
}
