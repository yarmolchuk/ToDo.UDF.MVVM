//
//  PriorityBadge.swift
//  ToDo.UDF.MVVM
//
//  Презентаційний пріоритет: те, що рендерять екрани (замість доменного
//  TaskPriority). VM створює його з TaskPriority і повертає назад на збереженні.
//

import SwiftUI

enum PriorityBadge: Hashable, CaseIterable {
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
        case .low: Color(hex: 0xC4C4C8)
        case .medium: Color(hex: 0x71717A)
        case .high: Color(hex: 0x16161A)
        }
    }
}

extension PriorityBadge {
    init(_ priority: TaskPriority) {
        switch priority {
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        }
    }

    var domain: TaskPriority {
        switch self {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}
