//
//  TaskListView.swift
//  ToDo.UDF.MVVM
//
//  Екран списку задач. Presentational: задачі живуть у локальному @State,
//  toggle перемикає виконання, а лічильники й прогрес — обчислювані.
//

import SwiftUI

struct TaskListView: View {
    @State private var tasks: [TodoTask] = TodoTask.sampleList

    var onAdd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeTasks: [TodoTask] { tasks.filter { !$0.isDone } }
    private var completedTasks: [TodoTask] { tasks.filter { $0.isDone } }
    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DotGridBackground()

            VStack(spacing: 0) {
                content
            }

            FloatingActionButton(action: onAdd)
                .padding(24)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                header

                ForEach(activeTasks) { task in
                    TaskListRow(task: task) { toggle(task) }
                }

                if !completedTasks.isEmpty {
                    SectionLabel(text: "Виконано · \(completedTasks.count)")
                        .padding(.top, 16)
                        .padding(.leading, 4)

                    ForEach(completedTasks) { task in
                        CompletedTaskRow(task: task) { toggle(task) }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 120) 
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Сьогодні · 24 черв")

                Text("Задачі")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("\(activeTasks.count) активних · \(completedTasks.count) виконано")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 12)

            ProgressRing(progress: progress)
                .padding(.top, 16)
        }
        .padding(.top, 8)
    }

    private func toggle(_ task: TodoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            tasks[index].isDone.toggle()
        }
    }
}

#Preview {
    TaskListView()
}
