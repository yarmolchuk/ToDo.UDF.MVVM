import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct UIFactoryTests {
    private func makeUseCases() -> TasksUseCases {
        DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: TodoTask.sampleList))
    }

    @Test func buildsTaskCreatedViewModelCarryingTask() {
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { _ in })
        #expect(vm.props.task == .sample)
    }

    @Test func builtViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }

    @Test func buildsTaskListViewModelWithEmptyInitialProps() {
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.taskListViewModel(onEffect: { _ in })
        #expect(vm.props.active.isEmpty)
        #expect(vm.props.completed.isEmpty)
    }

    @Test func builtTaskListViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.taskListViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }

    @Test func buildsNewTaskViewModel() {
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.newTaskViewModel(onEffect: { _ in })
        #expect(vm.props.canSave)
    }

    @Test func builtNewTaskViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory(useCases: makeUseCases())
        let vm = factory.newTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
