import SwiftUI

struct StreamingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(scaleFor(index: index))
                    .opacity(opacityFor(index: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func scaleFor(index: Int) -> CGFloat {
        let offset = Double(index) * 0.2
        return 0.5 + 0.5 * sin((phase + offset) * .pi)
    }

    private func opacityFor(index: Int) -> CGFloat {
        let offset = Double(index) * 0.2
        return 0.3 + 0.7 * sin((phase + offset) * .pi)
    }
}
