//
//  NewTaskView.swift
//  ToDo.UDF.MVVM
//
//  Форма створення задачі. Presentational + локальний @State; «Зберегти»
//  та «назад» — callbacks (заглушки в Preview).
//

import SwiftUI

struct NewTaskView: View {
    @State private var title = "Зустріч із інвестором"
    @State private var notes = "Підготувати дек та ключові метрики"
    @State private var when: TaskWhen = .today
    @State private var time = NewTaskView.defaultTime
    @State private var priority: TaskPriority = .medium
    @State private var isPickingTime = false

    var onSave: () -> Void = {}
    var onBack: () -> Void = {}
    var onAdd: () -> Void = {}
    var onToggleTheme: () -> Void = {}

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                NavBar(title: "Нова задача", onBack: onBack)
                    .padding(.top, 4)

                ScrollView {
                    formCard
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }

                Button("Зберегти", action: onSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $isPickingTime) {
            timePickerSheet
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(label: "Назва") {
                TextField("Назва задачі", text: $title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
            }

            divider

            field(label: "Нотатки") {
                TextField("Деталі", text: $notes, axis: .vertical)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1...6)
            }

            divider

            field(label: "Коли") {
                SegmentedControl(options: TaskWhen.allCases, selection: $when, label: \.title)
                    .accessibilityLabel("Коли")
            }

            field(label: "Час") {
                Button {
                    isPickingTime = true
                } label: {
                    TimeBadge(
                        time: Self.timeString(time),
                        fontSize: 16,
                        horizontalPadding: 14,
                        verticalPadding: 10
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Час")
                .accessibilityValue(Self.timeString(time))
            }

            divider

            field(label: "Пріоритет") {
                SegmentedControl(
                    options: TaskPriority.allCases,
                    selection: $priority,
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
            DatePicker("Час", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button("Готово") { isPickingTime = false }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .padding(.top, 24)
        .presentationDetents([.height(320)])
        .presentationBackground(AppColor.background)
    }

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}

#Preview {
    NewTaskView()
}
