//
//  TaskFlowCoordinator.swift
//  ToDo.UDF.MVVM
//

import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let router = Router()

    @ObservationIgnored private let factory: UIFactory

    init(factory: UIFactory) {
        self.factory = factory
    }

    convenience init() {
        self.init(factory: DefaultUIFactory(useCases: DataAssembly.makeLiveUseCases()))
    }

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .finishCreated:
            router.popToRoot()
        case .createTaskRequested:
            break
        case .saveRequested:
            break
        case .dismissForm:
            break
        }
    }

    func makeTaskCreatedViewModel(
        task: TaskSummary
    ) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory
            .taskCreatedViewModel(task: task, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeTaskListViewModel() -> AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> {
        factory
            .taskListViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory
            .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
}
