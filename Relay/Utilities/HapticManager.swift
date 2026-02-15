import UIKit

@MainActor
enum HapticManager {
    static func send() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func receive() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
