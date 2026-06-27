//
//  FloatingActionButton.swift
//  ToDo.UDF.MVVM
//
//  Плаваюча кнопка дії (FAB): чорний squircle із символом.
//

import SwiftUI

struct FloatingActionButton: View {
    var systemName: String = "plus"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColor.onInk)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColor.ink)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: AppColor.ink.opacity(0.25), radius: 16, x: 0, y: 8)
        .accessibilityLabel("Додати задачу")
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        FloatingActionButton()
    }
}
