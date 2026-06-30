import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct NewTaskViewModelTests {
    private func makeViewModel(
        repository: InMemoryTasksRepository? = nil,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) -> NewTaskViewModel {
        let repo = repository ?? InMemoryTasksRepository(seed: [])
        return NewTaskViewModel(addTask: DefaultAddTaskUseCase(repository: repo), onEffect: onEffect)
    }

    @Test func fieldEventsUpdateProps() {
        let vm = makeViewModel()
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
        let vm = makeViewModel()
        let newTime = Date(timeIntervalSince1970: 1_000_000)
        vm.onEvent(.timeChanged(newTime))
        #expect(vm.props.time == newTime)
    }

    @Test func emptyTitleDisablesCanSave() {
        let vm = makeViewModel()
        #expect(vm.props.canSave)               // демо-title непорожній
        vm.onEvent(.titleChanged("   "))
        #expect(!vm.props.canSave)
        vm.onEvent(.titleChanged("Назва"))
        #expect(vm.props.canSave)
    }

    @Test func timePickerEventsToggleFlag() {
        let vm = makeViewModel()
        vm.onEvent(.timePickerOpened)
        #expect(vm.props.isPickingTime)
        vm.onEvent(.timePickerClosed)
        #expect(!vm.props.isPickingTime)
    }

    @Test func savePersistsTaskAndEmitsEffect() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        var received: CoordinatorEffect?
        let vm = makeViewModel(repository: repository, onEffect: { received = $0 })
        vm.onEvent(.titleChanged("Купити каву"))
        vm.onEvent(.notesChanged(""))
        await vm.onAsyncEvent(.save)
        let stored = try await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored[0].title == "Купити каву")
        #expect(stored[0].notes == nil)             // порожні notes → nil
        #expect(received == .saveRequested(TaskSummary(title: "Купити каву", time: "09:30", priority: .medium)))
    }

    @Test func saveMapsDefaultTimeToHHmm() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        let vm = makeViewModel(repository: repository)
        await vm.onAsyncEvent(.save)                // демо-title непорожній, час 09:30
        let stored = try await repository.fetchAll()
        #expect(stored[0].time == "09:30")
    }

    @Test func saveDoesNotPersistWhenInvalid() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        var received: CoordinatorEffect?
        let vm = makeViewModel(repository: repository, onEffect: { received = $0 })
        vm.onEvent(.titleChanged(""))
        await vm.onAsyncEvent(.save)
        #expect(try await repository.fetchAll().isEmpty)
        #expect(received == nil)
    }

    @Test func backTappedEmitsDismiss() {
        var received: CoordinatorEffect?
        let vm = makeViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
