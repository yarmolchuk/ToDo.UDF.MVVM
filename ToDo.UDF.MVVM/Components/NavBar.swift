import SwiftUI

struct NavBar: View {
    let title: String
    var onBack: () -> Void = {}

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColor.card)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Назад")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        NavBar(title: "Нова задача")
    }
}
