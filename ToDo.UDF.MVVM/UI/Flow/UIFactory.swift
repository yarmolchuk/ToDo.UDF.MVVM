//
//  UIFactory.swift
//  ToDo.UDF.MVVM
//
//  Будує ViewModel-и фічі та інжектить у них onEffect-колбек.
//  Отримує TasksUseCases як DI-пакет для TaskListViewModel.
//

import Foundation

@MainActor
protocol UIFactory {
    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel

    func taskListViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel
}

@MainActor
final class DefaultUIFactory: UIFactory {
    private let useCases: TasksUseCases

    init(useCases: TasksUseCases) {
        self.useCases = useCases
    }

    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel {
        TaskCreatedViewModel(task: task, onEffect: onEffect)
    }

    func taskListViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel {
        TaskListViewModel(useCases: useCases, onEffect: onEffect)
    }

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel {
        NewTaskViewModel(onEffect: onEffect)
    }
}
