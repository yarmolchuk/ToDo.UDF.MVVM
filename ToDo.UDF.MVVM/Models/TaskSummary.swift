//
//  TaskSummary.swift
//  ToDo.UDF.MVVM
//
//  Легка presentational-модель задачі для екранів-підтверджень.
//

import Foundation

struct TaskSummary: Hashable {
    let title: String
    let time: String
    let priority: PriorityBadge
}

extension TaskSummary {
    static let sample = TaskSummary(
        title: "Зустріч із інвестором",
        time: "09:30",
        priority: .medium
    )
}
