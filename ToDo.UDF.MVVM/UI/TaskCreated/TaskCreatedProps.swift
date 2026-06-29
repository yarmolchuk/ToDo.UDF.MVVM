//
//  TaskCreatedProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події екрана «Задачу створено».
//

import Foundation

extension TaskCreatedView {
    struct Props: Equatable {
        let task: TaskSummary
        var appeared: Bool

        static func initial(task: TaskSummary) -> Props {
            Props(task: task, appeared: false)
        }
    }

    enum SyncEvent: Equatable {
        case continueTapped
    }

    enum AsyncEvent: Equatable {
        case appear(reduceMotion: Bool)
    }
}
