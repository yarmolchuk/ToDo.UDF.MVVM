import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct NewTaskViewModelTests {
    @Test func fieldEventsUpdateProps() {
        let vm = NewTaskViewModel()
        vm.onEvent(.titleChanged("Нова"))
        vm.onEvent(.notesChanged("деталі"))
        vm.onEvent(.whenChanged(.tomorrow))
        vm.onEvent(.priorityChanged(.high))
        #expect(vm.props.title == "Нова")
        #expect(vm.props.notes == "деталі")
        #expect(vm.props.when == .tomorrow)
        #expect(vm.props.priority == .high)
    }

    @Test func timeChangedUpdatesProps() {
        let vm = NewTaskViewModel()
        let newTime = Date(timeIntervalSince1970: 1_000_000)
        vm.onEvent(.timeChanged(newTime))
        #expect(vm.props.time == newTime)
    }

    @Test func emptyTitleDisablesCanSave() {
        let vm = NewTaskViewModel()
        #expect(vm.props.canSave)               // демо-title непорожній
        vm.onEvent(.titleChanged("   "))
        #expect(!vm.props.canSave)
        vm.onEvent(.titleChanged("Назва"))
        #expect(vm.props.canSave)
    }

    @Test func timePickerEventsToggleFlag() {
        let vm = NewTaskViewModel()
        vm.onEvent(.timePickerOpened)
        #expect(vm.props.isPickingTime)
        vm.onEvent(.timePickerClosed)
        #expect(!vm.props.isPickingTime)
    }

    @Test func saveTappedEmitsWhenCanSave() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.saveTapped)
        #expect(received == .saveRequested)
    }

    @Test func saveTappedDoesNotEmitWhenInvalid() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.titleChanged(""))
        vm.onEvent(.saveTapped)
        #expect(received == nil)
    }

    @Test func backTappedEmitsDismiss() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
