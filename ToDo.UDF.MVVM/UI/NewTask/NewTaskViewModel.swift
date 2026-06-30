//
//  NewTaskViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel форми створення задачі. Зберігає через AddTaskUseCase.
//

import SwiftUI
import OSLog

@MainActor
@Observable
final class NewTaskViewModel: UdfViewModel {
    typealias Props = NewTaskView.Props
    typealias SyncEvent = NewTaskView.SyncEvent
    typealias AsyncEvent = NewTaskView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let addTask: any AddTaskUseCase
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        addTask: any AddTaskUseCase,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.addTask = addTask
        self.onEffect = onEffect
        let title = "Зустріч із інвестором"
        self.props = Props(
            title: title,
            notes: "Підготувати дек та ключові метрики",
            when: .today,
            time: Self.defaultTime,
            priority: .medium,
            isPickingTime: false,
            canSave: Self.canSave(title: title)
        )
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .titleChanged(let v):
            props.title = v
            props.canSave = Self.canSave(title: v)
        case .notesChanged(let v):    props.notes = v
        case .whenChanged(let v):     props.when = v
        case .timeChanged(let v):     props.time = v
        case .priorityChanged(let v): props.priority = v
        case .timePickerOpened:       props.isPickingTime = true
        case .timePickerClosed:       props.isPickingTime = false
        case .backTapped:             onEffect(.dismissForm)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .save:
            guard props.canSave else { return }
            let task = TodoTask(
                title: props.title,
                notes: props.notes.isEmpty ? nil : props.notes,
                time: TaskTimeFormatter.string(from: props.time),
                priority: props.priority
            )
            do {
                try await addTask(task)
                let summary = TaskSummary(title: task.title, time: task.time, priority: task.priority)
                onEffect(.saveRequested(summary))
            } catch {
                // #5: лог; показ помилки користувачу — поза обсягом.
                Logger(subsystem: "ToDo.UDF.MVVM", category: "NewTask")
                    .error("Не вдалося зберегти задачу: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func canSave(title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }
}
