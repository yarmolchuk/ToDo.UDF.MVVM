import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let fetchTasks: any FetchTasksUseCase
    @ObservationIgnored private let toggleTask: any ToggleTaskUseCase
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        fetchTasks: any FetchTasksUseCase,
        toggleTask: any ToggleTaskUseCase,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.fetchTasks = fetchTasks
        self.toggleTask = toggleTask
        self.onEffect = onEffect
        self.props = Self.makeProps(from: [])
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
            await reload(animated: false)
        case let .toggle(id, reduceMotion):
            try? await toggleTask(id: id)
            await reload(animated: !reduceMotion)
        }
    }

    private func reload(animated: Bool) async {
        let tasks = (try? await fetchTasks()) ?? []
        let newProps = Self.makeProps(from: tasks)
        withAnimation(animated ? .spring(response: 0.4, dampingFraction: 0.85) : nil) {
            props = newProps
        }
    }

    private static func makeProps(from tasks: [TodoTask]) -> Props {
        let rows = tasks.map {
            TaskRow(id: $0.id, title: $0.title, notes: $0.notes,
                    time: $0.time, priority: TaskRow.PriorityBadge($0.priority), isDone: $0.isDone)
        }
        let active = rows.filter { !$0.isDone }
        let completed = rows.filter { $0.isDone }
        let progress = rows.isEmpty ? 0 : Double(completed.count) / Double(rows.count)
        return Props(active: active, completed: completed, progress: progress, headerDate: TaskDateFormatter.string(from: Date()))
    }
}
