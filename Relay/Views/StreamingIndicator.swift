import SwiftUI

struct StreamingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(.secondary)
            .frame(width: 10, height: 10)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}
