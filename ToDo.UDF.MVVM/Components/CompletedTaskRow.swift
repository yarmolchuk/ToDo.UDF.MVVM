//
//  CompletedTaskRow.swift
//  ToDo.UDF.MVVM
//
//  Рядок виконаної задачі: заповнений чекбокс і закреслена назва. Без картки.
//

import SwiftUI

struct CompletedTaskRow: View {
    let row: TaskRow
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(isOn: true, title: row.title, size: 32, action: onToggle)

            Text(row.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .strikethrough(true, color: AppColor.textSecondary)
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
    }
}

#Preview {
    CompletedTaskRow(row: TaskRow(id: UUID(), title: "Оновити залежності",
                                  notes: nil, time: "08:00", priority: .low, isDone: true))
        .padding()
        .background(AppColor.background)
}
