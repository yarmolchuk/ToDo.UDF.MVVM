//
//  TaskPriority.swift
//  ToDo.UDF.MVVM
//
//  Доменний пріоритет задачі. Без залежностей від UI.
//

enum TaskPriority: String, CaseIterable, Sendable {
    case low
    case medium
    case high
}
