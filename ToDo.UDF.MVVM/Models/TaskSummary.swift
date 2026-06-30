//
//  TaskSummary.swift
//  ToDo.UDF.MVVM
//
//  Легка presentational-модель задачі для екранів-підтверджень.
//  Колір пріоритету — у UI-розширенні (TaskSummaryCard), щоб модель лишалась без SwiftUI.
//

import Foundation

struct TaskSummary: Hashable {
    let title: String
    let time: String
    let priority: PriorityBadge

    // Власний пріоритет success-екрана. Створюється з TaskPriority у VM форми.
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

extension TaskSummary {
    static let sample = TaskSummary(
        title: "Зустріч із інвестором",
        time: "09:30",
        priority: .medium
    )
}
