//
//  ProgressRing.swift
//  ToDo.UDF.MVVM
//
//  Кільцевий індикатор прогресу з відсотком по центру.
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double          // частка [0, 1]
    var size: CGFloat = 88
    var lineWidth: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var percent: Int { Int((progress * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.subtleFill, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppColor.ink,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(percent)%")
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Прогрес")
        .accessibilityValue("\(percent)%")
    }
}

#Preview {
    ProgressRing(progress: 0.33)
        .padding()
        .background(AppColor.background)
}
