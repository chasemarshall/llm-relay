# Agent SF Symbol Icons — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users assign SF Symbol icons to agents, displayed in the agent list and new-chat menu.

**Architecture:** Add `iconName: String?` to Agent model, create an SFSymbolPickerView with searchable grid, wire it into AgentEditorView, and update display sites.

**Tech Stack:** SwiftUI, SwiftData, SF Symbols

---

### Task 1: Add iconName to Agent model

**Files:**
- Modify: `LLMChat/Models/Agent.swift:5-18`

**Step 1: Add the property and update init**

```swift
@Model
final class Agent {
    var id: UUID
    var name: String
    var modelId: String
    var systemPrompt: String
    var iconName: String?
    var createdAt: Date

    init(name: String, modelId: String, systemPrompt: String, iconName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.iconName = iconName
        self.createdAt = Date()
    }
}
```

**Step 2: Build to verify no errors**

Run: `xcodebuild -project LLMChat.xcodeproj -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add LLMChat/Models/Agent.swift
git commit -m "feat(agent): add iconName property to Agent model"
```

---

### Task 2: Create SFSymbolPickerView

**Files:**
- Create: `LLMChat/Views/SFSymbolPickerView.swift`

**Step 1: Create the picker view**

```swift
import SwiftUI

struct SFSymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String?
    @State private var searchText = ""

    private static let symbols: [String] = [
        // People
        "person.circle", "person.fill", "person.2", "figure.walk",
        "brain.head.profile", "brain", "eye", "hand.raised",
        // Tech
        "cpu", "desktopcomputer", "laptopcomputer", "terminal",
        "server.rack", "antenna.radiowaves.left.and.right", "network",
        "externaldrive", "cpu.fill", "memorychip",
        // Communication
        "bubble.left", "bubble.right", "bubble.left.and.bubble.right",
        "envelope", "phone", "megaphone", "bell",
        // Objects
        "book", "book.closed", "pencil", "paintbrush", "hammer",
        "wrench", "scissors", "lightbulb", "graduationcap",
        "briefcase", "cart", "airplane",
        // Nature
        "leaf", "flame", "bolt", "cloud", "moon", "sun.max",
        "star", "sparkles", "drop", "wind",
        // Shapes & Abstract
        "circle.hexagongrid", "square.grid.2x2", "wand.and.stars",
        "atom", "globe", "globe.americas", "target",
        "chart.bar", "chart.pie", "function",
        // Music & Media
        "music.note", "play.circle", "film", "camera",
        "photo", "headphones", "mic",
        // Health & Fitness
        "heart", "stethoscope", "pill", "cross.case",
        // Misc
        "flag", "mappin", "location", "tag", "lock.shield",
        "key", "doc.text", "folder", "tray",
        "gearshape", "slider.horizontal.3", "gauge",
        "questionmark.circle", "info.circle", "exclamationmark.triangle",
        "checkmark.seal", "rosette", "trophy"
    ]

    private var filtered: [String] {
        if searchText.isEmpty { return Self.symbols }
        return Self.symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filtered, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == symbol ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(selectedIcon == symbol ? Color.accentColor : .clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project LLMChat.xcodeproj -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add LLMChat/Views/SFSymbolPickerView.swift
git commit -m "feat(agent): add SF Symbol picker view"
```

---

### Task 3: Wire picker into AgentEditorView

**Files:**
- Modify: `LLMChat/Views/AgentEditorView.swift`

**Step 1: Add state and init for iconName**

Add `@State private var selectedIcon: String?` after line 11.

Update `init` to include:
```swift
_selectedIcon = State(initialValue: agent?.iconName)
```

Add `@State private var showIconPicker = false` after the selectedIcon state.

**Step 2: Add icon picker section to form**

Insert a new section at the top of the Form (before the Name section):

```swift
Section {
    Button {
        showIconPicker = true
    } label: {
        HStack {
            Image(systemName: selectedIcon ?? "person.circle")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
            Text("Choose Icon")
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    .buttonStyle(.plain)
} header: {
    Text("Icon")
}
```

**Step 3: Add sheet modifier**

Add after the existing `.toolbar` modifier:
```swift
.sheet(isPresented: $showIconPicker) {
    SFSymbolPickerView(selectedIcon: $selectedIcon)
}
```

**Step 4: Update save() to persist iconName**

In the `save()` function, add `agent.iconName = selectedIcon` for existing agents, and pass `iconName: selectedIcon` to the `Agent` init for new agents.

**Step 5: Build to verify**

Run: `xcodebuild -project LLMChat.xcodeproj -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add LLMChat/Views/AgentEditorView.swift
git commit -m "feat(agent): wire SF Symbol picker into agent editor"
```

---

### Task 4: Update display sites

**Files:**
- Modify: `LLMChat/Views/ConversationListView.swift:86`
- Modify: `LLMChat/Views/SettingsView.swift:96-114`

**Step 1: Update ConversationListView toolbar menu**

Change line 86 from:
```swift
Label(agent.name, systemImage: "person.circle")
```
to:
```swift
Label(agent.name, systemImage: agent.iconName ?? "person.circle")
```

**Step 2: Update SettingsView agents list**

In the agents section (around line 101), add the agent icon before the VStack. Replace the HStack content:

```swift
HStack(spacing: 12) {
    Image(systemName: agent.iconName ?? "person.circle")
        .font(.title3)
        .foregroundStyle(.secondary)
        .frame(width: 28)
    VStack(alignment: .leading, spacing: 4) {
        Text(agent.name)
            .font(.body)
            .foregroundStyle(.primary)
        Text(modelManager.modelName(for: agent.modelId))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    Spacer()
    Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
}
```

**Step 3: Build to verify**

Run: `xcodebuild -project LLMChat.xcodeproj -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add LLMChat/Views/ConversationListView.swift LLMChat/Views/SettingsView.swift
git commit -m "feat(agent): display custom icons in agent list and chat menu"
```
