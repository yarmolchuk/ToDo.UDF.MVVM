//
//  TaskRow.swift
//  ToDo.UDF.MVVM
//
//  Незмінна view-проекція рядка задачі. Її споживають Props і компоненти
//  рядків — не TodoTask. Мапінг TodoTask → TaskRow живе у ViewModel.
//

import Foundation

struct TaskRow: Equatable, Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let time: String
    let priority: PriorityBadge
    let isDone: Bool
}
