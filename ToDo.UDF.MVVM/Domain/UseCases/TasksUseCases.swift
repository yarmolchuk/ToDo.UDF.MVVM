//
//  TasksUseCases.swift
//  ToDo.UDF.MVVM
//
//  DI-набір use cases фічі задач (агрегує лише доменні протоколи).
//

struct TasksUseCases {
    let fetchTasks: any FetchTasksUseCase
    let addTask: any AddTaskUseCase
    let toggleTask: any ToggleTaskUseCase
}
