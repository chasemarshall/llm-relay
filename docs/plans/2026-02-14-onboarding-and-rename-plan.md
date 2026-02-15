# Onboarding Screen & Rename to Relay - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a 3-page onboarding flow and rename the app from "LLMChat" to "Relay" globally.

**Architecture:** TabView-based onboarding with page dots, gated by a UserDefaults boolean in SettingsManager. ContentView checks the flag and shows either OnboardingView or ConversationListView. Global rename covers project.yml, source directory, app struct, and display name.

**Tech Stack:** SwiftUI, SwiftData, XcodeGen, UserDefaults, KeychainManager

---

### Task 1: Add `hasCompletedOnboarding` to SettingsManager

**Files:**
- Modify: `LLMChat/Services/SettingsManager.swift`

**Step 1: Add the onboarding flag**

Add to `SettingsManager` enum:

```swift
private static let onboardingKey = "llmchat_has_completed_onboarding"

static var hasCompletedOnboarding: Bool {
    get { UserDefaults.standard.bool(forKey: onboardingKey) }
    set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
}
```

**Step 2: Commit**

```bash
git add LLMChat/Services/SettingsManager.swift
git commit -m "feat: add hasCompletedOnboarding flag to SettingsManager"
```

---

### Task 2: Create OnboardingView

**Files:**
- Create: `LLMChat/Views/OnboardingView.swift`

**Step 1: Create the onboarding view**

```swift
import SwiftUI

struct OnboardingView: View {
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

            // Bottom button area
            VStack(spacing: 12) {
                if currentPage < 2 {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Next")
                            .font(.body.weight(.semibold))
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
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))

                Link("Get your key at \(selectedProvider.keyPlaceholder)",
                     destination: URL(string: "https://\(selectedProvider.keyPlaceholder)")!)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
    }

    private func skipOnboarding() {
        SettingsManager.hasCompletedOnboarding = true
    }
}
```

**Step 2: Commit**

```bash
git add LLMChat/Views/OnboardingView.swift
git commit -m "feat: add OnboardingView with welcome, benefits, and setup pages"
```

---

### Task 3: Gate ContentView on onboarding flag

**Files:**
- Modify: `LLMChat/ContentView.swift`

**Step 1: Update ContentView**

Replace contents with:

```swift
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
```

Also update `OnboardingView` to accept an `onComplete` closure so the transition is reactive (instead of relying on UserDefaults polling). Add `var onComplete: () -> Void` property and call it in `completeOnboarding()` and `skipOnboarding()` after setting the flag.

**Step 2: Commit**

```bash
git add LLMChat/ContentView.swift LLMChat/Views/OnboardingView.swift
git commit -m "feat: gate app launch on onboarding completion"
```

---

### Task 4: Global rename LLMChat -> Relay

**Files:**
- Modify: `project.yml`
- Rename: `LLMChat/` -> `Relay/`
- Rename: `LLMChat/LLMChatApp.swift` -> `Relay/RelayApp.swift`
- Modify: `RelayApp.swift` (struct name)
- Modify: `Provider.swift` (HTTP-Referer)
- Regenerate: Xcode project via `xcodegen`

**Step 1: Update project.yml**

- `name: LLMChat` -> `name: Relay`
- `bundleIdPrefix: com.llmchat` -> `bundleIdPrefix: com.relay`
- Target name `LLMChat:` -> `Relay:`
- `path: LLMChat` -> `path: Relay`
- `PRODUCT_BUNDLE_IDENTIFIER: com.llmchat.app` -> `PRODUCT_BUNDLE_IDENTIFIER: com.relay.app`
- `PRODUCT_NAME: LLMChat` -> `PRODUCT_NAME: Relay`
- `INFOPLIST_KEY_CFBundleDisplayName: Plex` -> `INFOPLIST_KEY_CFBundleDisplayName: Relay`

**Step 2: Rename directories and files**

```bash
mv LLMChat Relay
mv Relay/LLMChatApp.swift Relay/RelayApp.swift
```

**Step 3: Update RelayApp.swift**

Change `struct LLMChatApp: App` -> `struct RelayApp: App`

**Step 4: Update Provider.swift**

Change HTTP-Referer from `https://llmchat.app` to `https://relay.app` (or remove).

**Step 5: Regenerate Xcode project**

```bash
rm -rf LLMChat.xcodeproj
xcodegen
```

This creates a fresh `Relay.xcodeproj` from project.yml.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: rename app from LLMChat to Relay"
```

---

### Task 5: Verify build

**Step 1: Build the project**

```bash
xcodebuild -project Relay.xcodeproj -scheme Relay -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 2: Fix any build errors and commit fixes**
