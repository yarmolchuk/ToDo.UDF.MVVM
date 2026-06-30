import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskListViewModelTests {
    private func makeViewModel(
        seed: [TodoTask] = TodoTask.sampleList,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) -> TaskListViewModel {
        let repository = InMemoryTasksRepository(seed: seed)
        return TaskListViewModel(
            fetchTasks: DefaultFetchTasksUseCase(repository: repository),
            toggleTask: DefaultToggleTaskUseCase(repository: repository),
            onEffect: onEffect
        )
    }

    @Test func loadSplitsTasks() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
        #expect(abs(vm.props.progress - 2.0 / 6.0) < 0.0001)
    }

    @Test func toggleActiveMovesToCompleted() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        let target = vm.props.active[0]
        await vm.onAsyncEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(!vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 3)
    }

    @Test func toggleCompletedMovesToActive() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        let target = vm.props.completed[0]
        await vm.onAsyncEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 1)
    }

    @Test func toggleUnknownIdDoesNothing() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        await vm.onAsyncEvent(.toggle(id: UUID(), reduceMotion: true))
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
    }

    @Test func addTappedEmitsCreateTaskRequested() {
        var received: CoordinatorEffect?
        let vm = makeViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
}
