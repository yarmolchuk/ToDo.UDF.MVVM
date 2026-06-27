//
//  CompletedTaskRow.swift
//  ToDo.UDF.MVVM
//
//  Рядок виконаної задачі: заповнений чекбокс і закреслена назва. Без картки.
//

import SwiftUI

struct CompletedTaskRow: View {
    let task: TodoTask
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(isOn: true, title: task.title, size: 32, action: onToggle)

            Text(task.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .strikethrough(true, color: AppColor.textSecondary)
                .accessibilityHidden(true)   // назву озвучує CheckboxButton

            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
    }
}

#Preview {
    CompletedTaskRow(task: TodoTask.sampleList[4])
        .padding()
        .background(AppColor.background)
}
