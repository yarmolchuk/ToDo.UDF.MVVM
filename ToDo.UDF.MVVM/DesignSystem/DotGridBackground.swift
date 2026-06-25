//
//  DotGridBackground.swift
//  ToDo.UDF.MVVM
//
//  Переюзовний фон: суцільна заливка + рівномірна сітка крапок.
//  Малюється одним проходом `Canvas`, тож недорогий і масштабований.
//

import SwiftUI

struct DotGridBackground: View {
    var background: Color = AppColor.background
    var dotColor: Color = AppColor.ink.opacity(0.08)
    var spacing: CGFloat = 22
    var dotRadius: CGFloat = 1.4

    var body: some View {
        Canvas { context, size in
            let dots = Path { path in
                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        path.addEllipse(
                            in: CGRect(
                                x: x - dotRadius,
                                y: y - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )
                        )
                        x += spacing
                    }
                    y += spacing
                }
            }
            context.fill(dots, with: .color(dotColor))
        }
        .background(background)
        .ignoresSafeArea()
    }
}

#Preview {
    DotGridBackground()
}
