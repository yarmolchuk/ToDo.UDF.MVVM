import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(AppColor.textSecondary)
    }
}

#Preview {
    SectionLabel(text: "Сьогодні · 24 черв")
        .padding()
        .background(AppColor.background)
}
