//
//  TaskListRow.swift
//  ToDo.UDF.MVVM
//
//  Картка активної задачі: чекбокс, назва, опис, час і пріоритет.
//

import SwiftUI

struct TaskListRow: View {
    let row: TaskRow
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            CheckboxButton(isOn: row.isDone, title: row.title, size: 23, action: onToggle)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.3)
                    .lineSpacing(4.8)
                    .foregroundStyle(AppColor.textPrimary)

                if let notes = row.notes {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                TimeBadge(time: row.time)
                PriorityTag(priority: row.priority)
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: 0x111113).opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x111113).opacity(0.04), radius: 1, x: 0, y: 1)
        .shadow(color: Color(hex: 0x111113).opacity(0.035), radius: 9, x: 0, y: 6)
    }
}

private struct PriorityTag: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(priority.indicatorColor)
                .frame(width: 6, height: 6)
            Text(priority.title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(AppColor.priorityLabel)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskListRow(row: TaskRow(id: UUID(), title: "Підготувати презентацію",
                                 notes: nil, time: "09:30", priority: .high, isDone: false))
        TaskListRow(row: TaskRow(id: UUID(), title: "Дзвінок з командою дизайну",
                                 notes: "Обговорити нову сітку інтерфейсу", time: "11:00",
                                 priority: .medium, isDone: false))
    }
    .padding()
    .background(AppColor.background)
}
