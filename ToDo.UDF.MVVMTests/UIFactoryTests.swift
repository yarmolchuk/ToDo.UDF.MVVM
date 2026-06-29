import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct UIFactoryTests {
    @Test func buildsTaskCreatedViewModelCarryingTask() {
        let factory = DefaultUIFactory()
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { _ in })
        #expect(vm.props.task == .sample)
    }

    @Test func builtViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory()
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }
}
