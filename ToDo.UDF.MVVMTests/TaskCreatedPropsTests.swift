import Testing
@testable import ToDo_UDF_MVVM

struct TaskCreatedPropsTests {
    @Test func initialPropsAreEquatableAndNotAppeared() {
        let a = TaskCreatedView.Props.initial(task: .sample)
        let b = TaskCreatedView.Props.initial(task: .sample)
        #expect(a == b)
        #expect(a.appeared == false)
        #expect(a.task == .sample)
    }
}
