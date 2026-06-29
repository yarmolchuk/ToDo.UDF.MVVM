import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    @Test func finishCreatedPopsToRoot() {
        let coordinator = TaskFlowCoordinator()
        coordinator.router.push("x")
        #expect(coordinator.router.path.count == 1)
        coordinator.handle(.finishCreated)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesViewModelCarryingTask() {
        let coordinator = TaskFlowCoordinator()
        let vm = coordinator.makeTaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }

    @Test func createTaskRequestedIsNoOp() {
        let coordinator = TaskFlowCoordinator()
        coordinator.handle(.createTaskRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesTaskListViewModelCarryingTasks() {
        let coordinator = TaskFlowCoordinator()
        let vm = coordinator.makeTaskListViewModel()
        #expect(vm.props.active.count + vm.props.completed.count == TodoTask.sampleList.count)
    }
}
