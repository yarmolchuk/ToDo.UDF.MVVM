//
//  TaskRow.swift
//  ToDo.UDF.MVVM
//
//  Незмінна view-проекція рядка задачі. Її споживають Props і компоненти
//  рядків — не TodoTask. Мапінг TodoTask → TaskRow живе у ViewModel.
//  Колір пріоритету — у UI-розширенні (TaskListRow), щоб модель лишалась без SwiftUI.
//

import Foundation

struct TaskRow: Equatable, Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let time: String
    let priority: PriorityBadge
    let isDone: Bool

    // Власний пріоритет списку. VM створює його з TaskPriority.
    enum PriorityBadge: Hashable, CaseIterable {
        case low
        case medium
        case high

        init(_ priority: TaskPriority) {
            switch priority {
            case .low: self = .low
            case .medium: self = .medium
            case .high: self = .high
            }
        }

        var title: String {
            switch self {
            case .low: "Низький"
            case .medium: "Середній"
            case .high: "Високий"
            }
        }
    }
}
