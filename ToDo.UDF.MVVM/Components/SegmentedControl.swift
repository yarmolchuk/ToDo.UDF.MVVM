//
//  SegmentedControl.swift
//  ToDo.UDF.MVVM
//
//  Сегментований вибір: обраний сегмент — чорний pill, решта — світлі.
//  Опційна кольорова крапка перед підписом (для пріоритету).
//

import SwiftUI

struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    
    @Binding var selection: Option
    
    let label: (Option) -> String
    var dotColor: (Option) -> Color? = { _ in nil }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        
        return Button {
            selection = option
        } label: {
            HStack(spacing: 7) {
                if let color = dotColor(option) {
                    Circle()
                        .fill(isSelected ? AppColor.onInk : color)
                        .frame(width: 7, height: 7)
                }
                Text(label(option))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? AppColor.onInk : AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColor.ink : AppColor.subtleFill)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct Demo: View {
        @State private var when: TaskWhen = .today
        @State private var priority: TaskPriority = .medium

        var body: some View {
            VStack(spacing: 20) {
                SegmentedControl(options: TaskWhen.allCases, selection: $when, label: \.title)
                SegmentedControl(
                    options: TaskPriority.allCases,
                    selection: $priority,
                    label: \.title,
                    dotColor: { $0.indicatorColor }
                )
            }
            .padding()
            .background(AppColor.background)
        }
    }
    return Demo()
}
