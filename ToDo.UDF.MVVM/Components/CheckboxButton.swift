import SwiftUI

struct CheckboxButton: View {
    let isOn: Bool
    let title: String
    var size: CGFloat = 44
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Checkbox(isOn: isOn, size: size)
                .frame(width: size, height: max(size, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Виконано" : "Не виконано")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Двічі торкніться, щоб змінити статус")
    }
}

#Preview {
    HStack(spacing: 16) {
        CheckboxButton(isOn: false, title: "Задача")
        CheckboxButton(isOn: true, title: "Задача", size: 32)
    }
    .padding()
    .background(AppColor.background)
}
