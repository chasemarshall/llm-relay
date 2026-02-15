import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = SettingsManager.hasCompletedOnboarding

    var body: some View {
        if hasCompletedOnboarding {
            ConversationListView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
