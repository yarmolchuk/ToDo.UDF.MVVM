//
//  UIFactory.swift
//  ToDo.UDF.MVVM
//
//  Будує ViewModel-и фічі та інжектить у них onEffect-колбек.
//

import Foundation

@MainActor
protocol UIFactory {
    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel

    func taskListViewModel(
        tasks: [TodoTask],
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel
}

@MainActor
final class DefaultUIFactory: UIFactory {
    nonisolated init() {}

    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel {
        TaskCreatedViewModel(task: task, onEffect: onEffect)
    }

    func taskListViewModel(
        tasks: [TodoTask],
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel {
        TaskListViewModel(tasks: tasks, onEffect: onEffect)
    }
}
