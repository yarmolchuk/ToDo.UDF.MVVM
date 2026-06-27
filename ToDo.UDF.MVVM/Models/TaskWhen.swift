//
//  TaskWhen.swift
//  ToDo.UDF.MVVM
//
//  Коли виконати задачу — вибір у формі створення.
//

import Foundation

enum TaskWhen: CaseIterable {
    case today
    case tomorrow
    case later

    var title: String {
        switch self {
        case .today: "Сьогодні"
        case .tomorrow: "Завтра"
        case .later: "Пізніше"
        }
    }
}
