# Onboarding Screen & Rename to Relay

## Overview

Add a 3-page onboarding flow and rename the app from "LLMChat" to "Relay".

## App Rename: LLMChat -> Relay

Global rename across all project files, directories, bundle identifiers, and code references.

- Directory: `LLMChat/` -> `Relay/`
- Xcode project: `LLMChat.xcodeproj/` -> `Relay.xcodeproj/`
- App struct: `LLMChatApp` -> `RelayApp`
- Bundle ID: `com.llmchat.app` -> `com.relay.app`
- Product name: `Relay`
- All pbxproj, project.yml, and scheme references

## Onboarding Flow

### Architecture

- **Navigation:** `TabView` with `.tabViewStyle(.page)` for native swipe + page dots
- **Gate:** `hasCompletedOnboarding` boolean in `SettingsManager` (UserDefaults)
- **Entry:** `ContentView.swift` checks flag, shows `OnboardingView` or `ConversationListView`
- **New file:** `Relay/Views/OnboardingView.swift`

### Page 1 - Welcome

- App icon centered
- "Relay" in large SF Pro Display
- Tagline: "Your keys. Your models. Your conversation."
- Minimal, just branding and core promise

### Page 2 - Why Relay

Three benefit rows with SF Symbols:

| Icon | Title | Description |
|------|-------|-------------|
| `lock.shield` | Private by design | API keys stay on your device, never touch our servers |
| `arrow.triangle.branch` | Any provider, one app | OpenRouter, OpenAI, or Anthropic - you choose |
| `sparkles` | Native & lightweight | Built for iOS, no bloat, just conversation |

### Page 3 - Get Started

- Provider picker (segmented: OpenRouter / OpenAI / Anthropic)
- Helper text with link to get API key for selected provider
- SecureField for API key entry
- "Get Started" button (enabled when key entered)
- "Skip for now" text button

### Completion

- Saves provider + API key via `SettingsManager` and `KeychainManager`
- Sets `hasCompletedOnboarding = true`
- Transitions to main app
