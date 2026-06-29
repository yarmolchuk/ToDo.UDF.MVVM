//
//  TaskListViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel списку задач. Тримає [TodoTask] як джерело істини
//  й деривує Props ([TaskRow] + progress).
//

import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private var tasks: [TodoTask]
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        tasks: [TodoTask] = TodoTask.sampleList,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.tasks = tasks
        self.onEffect = onEffect
        self.props = Self.makeProps(from: tasks)
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case let .toggle(id, reduceMotion):
            guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
            tasks[i].isDone.toggle()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                props = Self.makeProps(from: tasks)
            }
        case .addTapped:
            onEffect(.createTaskRequested)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {}

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
