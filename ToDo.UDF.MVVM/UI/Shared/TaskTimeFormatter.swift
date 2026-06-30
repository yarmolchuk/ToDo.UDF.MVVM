//
//  TaskTimeFormatter.swift
//  ToDo.UDF.MVVM
//
//  Спільне форматування часу задачі: Date → "HH:mm".
//

import Foundation

enum TaskTimeFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
