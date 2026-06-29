//
//  TaskFlowView.swift
//  ToDo.UDF.MVVM
//
//  Хост навігації todo-флоу: NavigationStack, прив'язаний до Router.
//

import SwiftUI

struct TaskFlowView: View {
    @State private var coordinator = TaskFlowCoordinator()

    var body: some View {
        @Bindable var router = coordinator.router
        NavigationStack(path: $router.path) {
            TaskCreatedView(viewModel: coordinator.makeTaskCreatedViewModel(task: .sample))
        }
    }
}

#Preview {
    TaskFlowView()
}
