import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskListViewModelTests {
    @Test func initialPropsSplitTasks() {
        let vm = TaskListViewModel()
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
        #expect(abs(vm.props.progress - 2.0 / 6.0) < 0.0001)
    }

    @Test func toggleActiveMovesToCompleted() {
        let vm = TaskListViewModel()
        let target = vm.props.active[0]
        vm.onEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(!vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 3)
    }

    @Test func toggleCompletedMovesToActive() {
        let vm = TaskListViewModel()
        let target = vm.props.completed[0]
        vm.onEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 1)
    }

    @Test func toggleUnknownIdDoesNothing() {
        let vm = TaskListViewModel()
        vm.onEvent(.toggle(id: UUID(), reduceMotion: true))
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
    }

    @Test func addTappedEmitsCreateTaskRequested() {
        var received: CoordinatorEffect?
        let vm = TaskListViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
}
