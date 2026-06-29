//
//  NewTaskProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події форми створення задачі.
//

import Foundation

extension NewTaskView {
    struct Props: Equatable {
        var title: String
        var notes: String
        var when: TaskWhen
        var time: Date
        var priority: TaskPriority
        var isPickingTime: Bool
        var canSave: Bool
    }

    enum SyncEvent: Equatable {
        case titleChanged(String)
        case notesChanged(String)
        case whenChanged(TaskWhen)
        case timeChanged(Date)
        case priorityChanged(TaskPriority)
        case timePickerOpened
        case timePickerClosed
        case saveTapped
        case backTapped
    }

    enum AsyncEvent: Equatable {}
}
