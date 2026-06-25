//
//  TaskCreatedView.swift
//  ToDo.UDF.MVVM
//
//  Екран-підтвердження «Задачу створено». Презентаційний: отримує готову
//  `TaskSummary` і колбек продовження, власної бізнес-логіки не має.
//

import SwiftUI

struct TaskCreatedView: View {
    let task: TaskSummary
    var onContinue: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                Spacer()

                SuccessBadge()
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

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

                TaskSummaryCard(task: task)
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 12)

                Spacer()

                Button("До списку", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
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
    TaskCreatedView(task: .sample)
}
