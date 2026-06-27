//
//  TodoTask.swift
//  ToDo.UDF.MVVM
//
//  Presentational-модель задачі для списку.
//

import Foundation

struct TodoTask: Identifiable {
    let id = UUID()
    var title: String
    var notes: String? = nil
    var time: String
    var priority: TaskPriority
    var isDone: Bool = false
}

extension TodoTask {
    // Демо-дані: 4 активні + 2 виконані → прогрес 33%.
    static let sampleList: [TodoTask] = [
        TodoTask(title: "Підготувати презентацію", time: "09:30", priority: .high),
        TodoTask(
            title: "Дзвінок з командою дизайну",
            notes: "Обговорити нову сітку інтерфейсу",
            time: "11:00",
            priority: .medium
        ),
        TodoTask(title: "Рев'ю пул-реквестів", time: "14:00", priority: .low),
        TodoTask(title: "Запланувати спринт", time: "16:30", priority: .medium),
        TodoTask(title: "Оновити залежності", time: "08:00", priority: .low, isDone: true),
        TodoTask(title: "Розгорнути на стейджинг", time: "18:00", priority: .high, isDone: true),
    ]
}
