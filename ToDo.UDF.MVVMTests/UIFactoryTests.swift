import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct UIFactoryTests {
    private func makeFactory(seed: [TodoTask] = TodoTask.sampleList) -> DefaultUIFactory {
        DefaultUIFactory(useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed)))
    }

    @Test func buildsTaskCreatedViewModelCarryingTask() {
        let vm = makeFactory().taskCreatedViewModel(task: .sample, onEffect: { _ in })
        #expect(vm.props.task == .sample)
    }

    @Test func builtTaskCreatedViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().taskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }

    @Test func buildsTaskListViewModel() async {
        let vm = makeFactory().taskListViewModel(onEffect: { _ in })
        await vm.onAsyncEvent(.load)
        #expect(vm.props.active.count + vm.props.completed.count == TodoTask.sampleList.count)
    }

    @Test func builtTaskListViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().taskListViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }

    @Test func buildsNewTaskViewModel() {
        let vm = makeFactory().newTaskViewModel(onEffect: { _ in })
        #expect(vm.props.canSave)
    }

    @Test func builtNewTaskViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().newTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
