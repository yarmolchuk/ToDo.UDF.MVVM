//
//  TimeBadge.swift
//  ToDo.UDF.MVVM
//
//  Сірий pill із часом (monospaced). Спільний для списку та форми.
//

import SwiftUI

struct TimeBadge: View {
    let time: String
    var fontSize: CGFloat = 11.5
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 3

    var body: some View {
        Text(time)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(AppColor.chipText)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(AppColor.subtleFill)
            )
    }
}

#Preview {
    TimeBadge(time: "09:30")
        .padding()
        .background(AppColor.background)
}
