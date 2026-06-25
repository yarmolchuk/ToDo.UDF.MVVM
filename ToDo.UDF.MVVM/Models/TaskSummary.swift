//
//  TaskSummary.swift
//  ToDo.UDF.MVVM
//
//  Легка presentational-модель задачі для екранів-підтверджень.
//  Тут навмисно немає логіки збереження — лише те, що показуємо.
//

import SwiftUI

enum TaskPriority {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: "Низький"
        case .medium: "Середній"
        case .high: "Високий"
        }
    }
    
    var indicatorColor: Color {
        switch self {
        case .low: Color(hex: 0xBDBDBD)
        case .medium: Color(hex: 0x7C7C7C)
        case .high: Color(hex: 0xE5484D)
        }
    }
}

struct TaskSummary {
    let title: String
    let time: String
    let priority: TaskPriority
}

extension TaskSummary {
    static let sample = TaskSummary(
        title: "Зустріч із інвестором",
        time: "09:30",
        priority: .medium
    )
}
