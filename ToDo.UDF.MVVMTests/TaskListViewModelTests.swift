import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskListViewModelTests {
    private func makeUseCases(seed: [TodoTask] = TodoTask.sampleList) -> TasksUseCases {
        DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed))
    }

    @Test func initialPropsAreEmpty() {
        let vm = TaskListViewModel(useCases: makeUseCases(), onEffect: { _ in })
        #expect(vm.props.active.isEmpty)
        #expect(vm.props.completed.isEmpty)
        #expect(vm.props.progress == 0)
    }

    @Test func loadFetchesAndSplitsTasks() async throws {
        let vm = TaskListViewModel(useCases: makeUseCases(), onEffect: { _ in })
        await vm.onAsyncEvent(.load)
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
        #expect(abs(vm.props.progress - 2.0 / 6.0) < 0.0001)
    }

    @Test func toggleActiveMovesToCompleted() async throws {
        let vm = TaskListViewModel(useCases: makeUseCases(), onEffect: { _ in })
        await vm.onAsyncEvent(.load)
        let target = vm.props.active[0]
        await vm.onAsyncEvent(.toggle(id: target.id))
        #expect(!vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 3)
    }

    @Test func toggleCompletedMovesToActive() async throws {
        let vm = TaskListViewModel(useCases: makeUseCases(), onEffect: { _ in })
        await vm.onAsyncEvent(.load)
        let target = vm.props.completed[0]
        await vm.onAsyncEvent(.toggle(id: target.id))
        #expect(vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 1)
    }

    @Test func addTappedEmitsCreateTaskRequested() {
        var received: CoordinatorEffect?
        let vm = TaskListViewModel(useCases: makeUseCases(), onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
}
