//
//  TaskListRow.swift
//  ToDo.UDF.MVVM
//
//  Картка активної задачі: чекбокс, назва, опис, час і пріоритет.
//

import SwiftUI

struct TaskListRow: View {
    let task: TodoTask
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            CheckboxButton(isOn: task.isDone, title: task.title, size: 23, action: onToggle)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.3)
                    .lineSpacing(4.8)
                    .foregroundStyle(AppColor.textPrimary)

                if let notes = task.notes {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                TimeBadge(time: task.time)
                PriorityTag(priority: task.priority)
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
        TaskListRow(task: TodoTask.sampleList[0])
        TaskListRow(task: TodoTask.sampleList[1])
    }
    .padding()
    .background(AppColor.background)
}
