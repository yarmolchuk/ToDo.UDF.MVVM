//
//  AppTheme.swift
//  ToDo.UDF.MVVM
//
//  Дизайн-токени застосунку. Кольори зібрані в одному місці, щоб усі
//  екрани лишалися консистентними. За потреби (dark mode) їх легко
//  перенести в Asset Catalog без зміни місць використання.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

/// Палітра застосунку.
enum AppColor {
    static let background = Color(hex: 0xF3F1EC)
    static let ink = Color(hex: 0x16161A)
    static let card = Color.white
    static let textPrimary = Color(hex: 0x16161A)
    static let textSecondary = Color(hex: 0xA1A09A)
    static let onInk = Color.white
    static let subtleFill = Color(hex: 0xF2F1ED)      // --chip
    static let stroke = Color(hex: 0xD6D5D0)          // рамка чекбокса
    static let chipText = Color(hex: 0x52524E)        // текст чипа часу
    static let priorityLabel = Color(hex: 0xB4B3AD)   // лейбл пріоритету
}
