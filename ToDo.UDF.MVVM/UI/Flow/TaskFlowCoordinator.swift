import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let onComplete: (any Coordinator) -> Void

    @ObservationIgnored private let dependencies: TaskFlowFeature.Dependencies
    @ObservationIgnored private lazy var factory: UIFactory = dependencies.factory(dependencies)

    @ObservationIgnored lazy var listViewModel: AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> =
        factory.taskListViewModel(onEffect: { [weak self] effect in self?.handle(effect) }).eraseToAnyViewModel()

    var router: Router { dependencies.router }

    init(
        dependencies: TaskFlowFeature.Dependencies,
        onComplete: @escaping (any Coordinator) -> Void
    ) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    func start() {}

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .createTaskRequested:
            router.push(TaskRoute.newTask)
        case .saveRequested(let summary):
            Task { await listViewModel.onAsync(.load) }
            router.push(TaskRoute.created(summary))
        case .dismissForm:
            router.pop()
        case .finishCreated:
            router.popToRoot()
        }
    }

    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory
            .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeTaskCreatedViewModel(
        task: TaskSummary
    ) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory
            .taskCreatedViewModel(task: task, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
}
