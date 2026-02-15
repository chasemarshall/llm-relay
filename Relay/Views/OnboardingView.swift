import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var selectedProvider: Provider = .openRouter
    @State private var apiKey = ""

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                benefitsPage.tag(1)
                setupPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if currentPage < 2 {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Next")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                } else {
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        skipOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("AppIcon")
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("Relay")
                .font(.system(size: 40, weight: .bold, design: .default))
            Text("Your keys. Your models.\nYour conversation.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var benefitsPage: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Why Relay")
                .font(.system(size: 32, weight: .bold))

            VStack(alignment: .leading, spacing: 24) {
                benefitRow(icon: "lock.shield", title: "Private by design", description: "Your API keys stay on your device. No accounts, no tracking.")
                benefitRow(icon: "arrow.triangle.branch", title: "Any provider, one app", description: "OpenRouter, OpenAI, or Anthropic — you choose.")
                benefitRow(icon: "sparkles", title: "Native & lightweight", description: "Built for iOS. No bloat, just conversation.")
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var setupPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Get Started")
                .font(.system(size: 32, weight: .bold))
            Text("Choose your AI provider and enter your API key.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(Provider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Link("Get your key at \(selectedProvider.keyPlaceholder)",
                     destination: URL(string: "https://\(selectedProvider.keyPlaceholder)")!)
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func completeOnboarding() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsManager.aiProvider = selectedProvider
        KeychainManager.setApiKey(trimmed, for: selectedProvider)
        SettingsManager.hasCompletedOnboarding = true
        onComplete()
    }

    private func skipOnboarding() {
        SettingsManager.hasCompletedOnboarding = true
        onComplete()
    }
}
