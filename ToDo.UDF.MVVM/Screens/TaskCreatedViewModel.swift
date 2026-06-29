//
//  TaskCreatedViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel екрана «Задачу створено».
//

import SwiftUI

@MainActor
@Observable
final class TaskCreatedViewModel: UdfViewModel {
    typealias Props = TaskCreatedView.Props
    typealias SyncEvent = TaskCreatedView.SyncEvent
    typealias AsyncEvent = TaskCreatedView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(task: TaskSummary, onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }) {
        self.props = .initial(task: task)
        self.onEffect = onEffect
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .continueTapped:
            onEffect(.finishCreated)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .appear(let reduceMotion):
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
                props.appeared = true
            }
        }
    }
}
