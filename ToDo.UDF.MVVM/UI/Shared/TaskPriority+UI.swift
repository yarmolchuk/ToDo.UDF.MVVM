//
//  TaskPriority+UI.swift
//  ToDo.UDF.MVVM
//
//  Презентаційне розширення доменного TaskPriority (заголовок, колір-індикатор).
//

import SwiftUI

extension TaskPriority {
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
