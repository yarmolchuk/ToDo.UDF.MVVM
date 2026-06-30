//
//  TaskWhen.swift
//  ToDo.UDF.MVVM
//
//  Коли виконати задачу — модель вибору форми (без презентації).
//  Презентаційний відповідник — NewTaskView.Props.When.
//

import Foundation

enum TaskWhen: CaseIterable {
    case today
    case tomorrow
    case later
}
