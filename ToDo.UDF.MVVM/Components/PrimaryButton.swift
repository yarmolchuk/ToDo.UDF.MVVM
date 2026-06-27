//
//  PrimaryButton.swift
//  ToDo.UDF.MVVM
//
//  Основний стиль кнопки: чорна «пігулка» на всю ширину з білим текстом.
//  Винесено в `ButtonStyle`, щоб перевикористовувати на інших екранах
//  і безкоштовно мати коректний стан натискання.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColor.onInk)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColor.ink)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        Button("До списку") {}
            .buttonStyle(PrimaryButtonStyle())
            .padding(24)
    }
}
