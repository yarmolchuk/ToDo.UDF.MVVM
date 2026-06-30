//
//  TaskRoute.swift
//  ToDo.UDF.MVVM
//
//  Маршрути навігаційного стека todo-флоу.
//

enum TaskRoute: Hashable {
    case newTask
    case created(TaskSummary)
}
