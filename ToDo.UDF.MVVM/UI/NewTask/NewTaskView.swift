//
//  NewTaskView.swift
//  ToDo.UDF.MVVM
//
//  Форма створення задачі. Керується UDF через AnyUdfViewModel:
//  поля біндяться інлайн (get з props, set через onEvent).
//

import SwiftUI

struct NewTaskView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                NavBar(title: "Нова задача", onBack: { viewModel.onEvent(.backTapped) })
                    .padding(.top, 4)

                ScrollView {
                    formCard
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }

                Button("Зберегти") { Task { await viewModel.onAsync(.save) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.props.canSave)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.props.isPickingTime },
            set: { viewModel.onEvent($0 ? .timePickerOpened : .timePickerClosed) }
        )) {
            timePickerSheet
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(label: "Назва") {
                TextField("Назва задачі", text: Binding(
                    get: { viewModel.props.title },
                    set: { viewModel.onEvent(.titleChanged($0)) }
                ))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
            }

            divider

            field(label: "Нотатки") {
                TextField("Деталі", text: Binding(
                    get: { viewModel.props.notes },
                    set: { viewModel.onEvent(.notesChanged($0)) }
                ), axis: .vertical)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1...6)
            }

            divider

            field(label: "Коли") {
                SegmentedControl(
                    options: Props.When.allCases,
                    selection: Binding(
                        get: { viewModel.props.when },
                        set: { viewModel.onEvent(.whenChanged($0)) }
                    ),
                    label: \.title
                )
                .accessibilityLabel("Коли")
            }

            field(label: "Час") {
                Button {
                    viewModel.onEvent(.timePickerOpened)
                } label: {
                    TimeBadge(
                        time: TaskTimeFormatter.string(from: viewModel.props.time),
                        fontSize: 16,
                        horizontalPadding: 14,
                        verticalPadding: 10
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Час")
                .accessibilityValue(TaskTimeFormatter.string(from: viewModel.props.time))
            }

            divider

            field(label: "Пріоритет") {
                SegmentedControl(
                    options: PriorityBadge.allCases,
                    selection: Binding(
                        get: { viewModel.props.priority },
                        set: { viewModel.onEvent(.priorityChanged($0)) }
                    ),
                    label: \.title,
                    dotColor: { $0.indicatorColor }
                )
                .accessibilityLabel("Пріоритет")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColor.card)
        )
        .shadow(color: AppColor.ink.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private func field<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: label)
            content()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColor.stroke.opacity(0.5))
            .frame(height: 1)
    }

    private var timePickerSheet: some View {
        VStack(spacing: 0) {
            DatePicker("Час", selection: Binding(
                get: { viewModel.props.time },
                set: { viewModel.onEvent(.timeChanged($0)) }
            ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button("Готово") { viewModel.onEvent(.timePickerClosed) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .padding(.top, 24)
        .presentationDetents([.height(320)])
        .presentationBackground(AppColor.background)
    }

}

#Preview {
    NewTaskView(viewModel: NewTaskViewModel(
        addTask: DefaultAddTaskUseCase(repository: InMemoryTasksRepository())
    ).eraseToAnyViewModel())
}
