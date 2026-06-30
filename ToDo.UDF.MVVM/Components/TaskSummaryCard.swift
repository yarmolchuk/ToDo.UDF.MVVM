import SwiftUI

struct TaskSummaryCard: View {
    let task: TaskSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(task.priority.indicatorColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("\(task.time) · \(task.priority.title)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColor.card)
        )
        .shadow(color: AppColor.ink.opacity(0.06), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.time), пріоритет \(task.priority.title)")
    }
}

extension TaskSummary.PriorityBadge {
    var indicatorColor: Color {
        switch self {
        case .low: Color(hex: 0xC4C4C8)
        case .medium: Color(hex: 0x71717A)
        case .high: Color(hex: 0x16161A)
        }
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        TaskSummaryCard(task: .sample)
    }
}
