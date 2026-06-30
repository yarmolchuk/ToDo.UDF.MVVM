//
//  TaskFlowView.swift
//  ToDo.UDF.MVVM
//
//  Хост навігації todo-флоу: NavigationStack зі списком як коренем,
//  форма й success — push через TaskRoute.
//

import SwiftUI

struct TaskFlowView: View {
    @State private var coordinator: TaskFlowCoordinator

    init(useCases: TasksUseCases) {
        let router = Router()
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        _coordinator = State(initialValue: TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in }))
    }

    var body: some View {
        @Bindable var router = coordinator.router
        NavigationStack(path: $router.path) {
            TaskListView(viewModel: coordinator.listViewModel)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: TaskRoute.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .onAppear { coordinator.start() }
    }

    @ViewBuilder
    private func destination(for route: TaskRoute) -> some View {
        switch route {
        case .newTask:
            NewTaskView(viewModel: coordinator.makeNewTaskViewModel())
        case .created(let summary):
            TaskCreatedView(viewModel: coordinator.makeTaskCreatedViewModel(task: summary))
        }
    }
}

#Preview {
    TaskFlowView(useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository()))
}
