//
//  TaskListProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події екрана списку задач.
//

import Foundation

extension TaskListView {
    struct Props: Equatable {
        var active: [TaskRow]
        var completed: [TaskRow]
        var progress: Double
    }

    enum SyncEvent: Equatable {
        case addTapped
    }

    enum AsyncEvent: Equatable {
        case load
        case toggle(id: UUID)
    }
}
