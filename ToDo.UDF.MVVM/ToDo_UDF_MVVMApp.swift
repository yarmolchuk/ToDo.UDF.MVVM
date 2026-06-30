//
//  ToDo_UDF_MVVMApp.swift
//  ToDo.UDF.MVVM
//

import SwiftUI
import SwiftData

@main
struct ToDo_UDF_MVVMApp: App {
    @State private var modelContainer: ModelContainer
    private let tasksUseCases: TasksUseCases

    init() {
        let container = AppComposition.bootstrap()
        _modelContainer = State(initialValue: container)
        tasksUseCases = AppComposition.tasksUseCases(container: container)
    }

    var body: some Scene {
        WindowGroup {
            TaskFlowView(useCases: tasksUseCases)
                .modelContainer(modelContainer)
        }
    }
}
