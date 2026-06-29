//
//  TaskFlowCoordinator.swift
//  ToDo.UDF.MVVM
//
//  Координатор todo-флоу: тримає Router/UIFactory, обробляє ефекти.
//

import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let router = Router()

    @ObservationIgnored private let factory: UIFactory

    init(factory: UIFactory = DefaultUIFactory()) {
        self.factory = factory
    }

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .finishCreated:
            router.popToRoot()
        }
    }

    func makeTaskCreatedViewModel(
        task: TaskSummary
    ) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory
            .taskCreatedViewModel(task: task, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
}
