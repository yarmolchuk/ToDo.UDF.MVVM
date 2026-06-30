//
//  TaskListViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel списку задач. Завантажує задачі через FetchTasksUseCase
//  і перемикає через ToggleTaskUseCase (обидва — async).
//

import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let useCases: TasksUseCases
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        useCases: TasksUseCases,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.useCases = useCases
        self.onEffect = onEffect
        self.props = Props(active: [], completed: [], progress: 0)
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .addTapped:
            onEffect(.createTaskRequested)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .load:
            await reload()
        case let .toggle(id):
            try? await useCases.toggleTask(id: id)
            await reload()
        }
    }

    private func reload() async {
        let tasks = (try? await useCases.fetchTasks()) ?? []
        props = Self.makeProps(from: tasks)
    }

    private static func makeProps(from tasks: [TodoTask]) -> Props {
        let rows = tasks.map {
            TaskRow(id: $0.id, title: $0.title, notes: $0.notes,
                    time: $0.time, priority: $0.priority, isDone: $0.isDone)
        }
        let active = rows.filter { !$0.isDone }
        let completed = rows.filter { $0.isDone }
        let progress = rows.isEmpty ? 0 : Double(completed.count) / Double(rows.count)
        return Props(active: active, completed: completed, progress: progress)
    }
}
