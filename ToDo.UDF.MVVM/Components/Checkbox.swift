import SwiftUI

struct Checkbox: View {
    let isOn: Bool
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isOn ? AppColor.ink : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppColor.stroke, lineWidth: 1.6)
                    .opacity(isOn ? 0 : 1)
            }
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.52, weight: .bold))
                    .foregroundStyle(AppColor.onInk)
                    .opacity(isOn ? 1 : 0)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        Checkbox(isOn: false)
        Checkbox(isOn: true)
        Checkbox(isOn: true, size: 32)
    }
    .padding()
    .background(AppColor.background)
}
