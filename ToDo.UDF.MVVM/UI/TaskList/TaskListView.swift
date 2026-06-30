import SwiftUI

struct TaskListView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DotGridBackground()

            VStack(spacing: 0) {
                content
            }

            FloatingActionButton(action: { viewModel.onEvent(.addTapped) })
                .padding(24)
        }
        .sensoryFeedback(.selection, trigger: viewModel.props.completed.count)
        .task { await viewModel.onAsync(.load) }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                header

                if viewModel.props.active.isEmpty {
                    ContentUnavailableView(
                        "Усе виконано",
                        systemImage: "checkmark.circle",
                        description: Text("Активних задач немає")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(viewModel.props.active) { row in
                        TaskListRow(row: row) {
                            Task { await viewModel.onAsync(.toggle(id: row.id, reduceMotion: reduceMotion)) }
                        }
                    }
                }

                if !viewModel.props.completed.isEmpty {
                    SectionLabel(text: "Виконано · \(viewModel.props.completed.count)")
                        .padding(.top, 16)
                        .padding(.leading, 4)

                    ForEach(viewModel.props.completed) { row in
                        CompletedTaskRow(row: row) {
                            Task { await viewModel.onAsync(.toggle(id: row.id, reduceMotion: reduceMotion)) }
                        }
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

                Text("\(viewModel.props.active.count) активних · \(viewModel.props.completed.count) виконано")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 12)

            ProgressRing(progress: viewModel.props.progress)
                .padding(.top, 16)
        }
        .padding(.top, 8)
    }
}

#Preview {
    let repository = InMemoryTasksRepository()
    TaskListView(viewModel: TaskListViewModel(
        fetchTasks: DefaultFetchTasksUseCase(repository: repository),
        toggleTask: DefaultToggleTaskUseCase(repository: repository)
    ).eraseToAnyViewModel())
}
