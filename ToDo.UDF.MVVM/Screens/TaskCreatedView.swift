//
//  TaskCreatedView.swift
//  ToDo.UDF.MVVM
//
//  Екран-підтвердження «Задачу створено». Презентаційний: отримує готову
//  `TaskSummary` і колбек продовження, власної бізнес-логіки не має.
//

import SwiftUI

struct TaskCreatedView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                Spacer()

                SuccessBadge()
                    .scaleEffect(viewModel.props.appeared ? 1 : 0.6)
                    .opacity(viewModel.props.appeared ? 1 : 0)

                Text("ГОТОВО")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityLabel("Готово")
                    .padding(.top, 28)

                Text("Задачу створено")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                TaskSummaryCard(task: viewModel.props.task)
                    .padding(.top, 28)
                    .opacity(viewModel.props.appeared ? 1 : 0)
                    .offset(y: viewModel.props.appeared ? 0 : 12)

                Spacer()

                Button("До списку") { viewModel.onEvent(.continueTapped) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .task {
            await viewModel.onAsync(.appear(reduceMotion: reduceMotion))
        }
    }
}

private struct SuccessBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.ink)
                .frame(width: 188, height: 188)

            Image(systemName: "checkmark")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(AppColor.onInk)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    TaskCreatedView(viewModel: TaskCreatedViewModel(task: .sample).eraseToAnyViewModel())
}
