import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskCreatedViewModelTests {
    @Test func continueTappedInvokesCallback() {
        var continued = false
        let vm = TaskCreatedViewModel(task: .sample, onContinue: { continued = true })
        vm.onEvent(.continueTapped)
        #expect(continued)
    }

    @Test func appearSetsAppeared() async {
        let vm = TaskCreatedViewModel(task: .sample)
        #expect(vm.props.appeared == false)
        await vm.onAsyncEvent(.appear(reduceMotion: true))
        #expect(vm.props.appeared)
    }

    @Test func initialPropsCarryTask() {
        let vm = TaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }
}
