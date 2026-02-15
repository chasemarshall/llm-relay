# Settings View Polish & Reorganization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize SettingsView for better UX — merge API key sections, add cancel button, add "Clear All Chats", normalize consistency across SettingsView and AgentEditorView.

**Architecture:** Single-file restructure of `SettingsView.swift` with a small consistency fix in `AgentEditorView.swift`. No new files needed. All changes are UI-layer only.

**Tech Stack:** SwiftUI, SwiftData

---

### Task 1: Add cancel button and normalize toolbar

**Files:**
- Modify: `LLMChat/Views/SettingsView.swift:172-195` (toolbar block)

**Step 1: Add cancel ToolbarItem**

In the `.toolbar` block (line 172), add a leading cancel button before the existing confirmationAction item:

```swift
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .fontWeight(.medium)
        }
    }
    ToolbarItem(placement: .confirmationAction) {
        // ... existing save button unchanged ...
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add LLMChat/Views/SettingsView.swift
git commit -m "feat(settings): add cancel button to toolbar"
```

---

### Task 2: Merge API Keys into one section

**Files:**
- Modify: `LLMChat/Views/SettingsView.swift:36-61` (OpenRouter + Web Search sections)

**Step 1: Replace two sections with one combined section**

Replace lines 37–61 (the OpenRouter section and Web Search section) with a single "API Keys" section:

```swift
Section {
    SecureField("OpenRouter", text: $apiKey)
        .textContentType(.password)
        .autocorrectionDisabled()
    Picker("Search Provider", selection: $searchProvider) {
        ForEach(SearchProvider.allCases, id: \.self) { provider in
            Text(provider.displayName).tag(provider)
        }
    }
    .pickerStyle(.segmented)
    SecureField("Search API Key", text: $searchApiKey)
        .textContentType(.password)
        .autocorrectionDisabled()
} header: {
    Text("API Keys")
} footer: {
    Text("OpenRouter: openrouter.ai/keys · Search: \(searchProvider.keyPlaceholder)")
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add LLMChat/Views/SettingsView.swift
git commit -m "feat(settings): merge API keys into single section"
```

---

### Task 3: Normalize section header syntax

**Files:**
- Modify: `LLMChat/Views/SettingsView.swift` — the `Section("Default Model")` shorthand
- Modify: `LLMChat/Views/AgentEditorView.swift` — `Section("Name")` and `Section("Model")` shorthands

**Step 1: In SettingsView, change the Default Model section**

Replace:
```swift
Section("Default Model") {
```

With:
```swift
Section {
    // ... picker content unchanged ...
} header: {
    Text("Default Model")
}
```

**Step 2: In AgentEditorView, change Name and Model sections**

Replace:
```swift
Section("Name") {
    TextField("e.g. Code Assistant", text: $name)
}

Section("Model") {
```

With:
```swift
Section {
    TextField("e.g. Code Assistant", text: $name)
} header: {
    Text("Name")
}

Section {
```
And close the Model section with:
```swift
} header: {
    Text("Model")
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add LLMChat/Views/SettingsView.swift LLMChat/Views/AgentEditorView.swift
git commit -m "refactor: normalize section header syntax across settings views"
```

---

### Task 4: Add "Clear All Chats" section with confirmation alert

**Files:**
- Modify: `LLMChat/Views/SettingsView.swift` — add state var + new section + alert modifier

**Step 1: Add state variable**

After line 17 (`@State private var editingAgent: Agent?`), add:

```swift
@State private var showClearChatsAlert = false
```

**Step 2: Add Data section after Memories section**

After the Memories section closing brace (after the footer), add:

```swift
Section {
    Button(role: .destructive) {
        showClearChatsAlert = true
    } label: {
        Text("Clear All Chats")
    }
} header: {
    Text("Data")
}
```

**Step 3: Add alert modifier**

Add this after the `.sheet(item: $editingAgent)` modifier (around line 213):

```swift
.alert("Clear All Chats?", isPresented: $showClearChatsAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Clear All", role: .destructive) {
        do {
            try modelContext.delete(model: Conversation.self)
            try modelContext.save()
        } catch { }
    }
} message: {
    Text("This will permanently delete all conversations and messages. This cannot be undone.")
}
```

**Step 4: Build and verify**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add LLMChat/Views/SettingsView.swift
git commit -m "feat(settings): add Clear All Chats with confirmation alert"
```

---

### Task 5: Add keyboard dismiss and normalize AgentEditorView save button

**Files:**
- Modify: `LLMChat/Views/SettingsView.swift:169` — after `Form {` closing brace
- Modify: `LLMChat/Views/AgentEditorView.swift:58-73` — toolbar button style

**Step 1: Add scrollDismissesKeyboard to SettingsView Form**

After the `Form { ... }` closing brace and before `.navigationTitle("Settings")`, add:

```swift
.scrollDismissesKeyboard(.interactively)
```

**Step 2: Normalize AgentEditorView save button**

Replace the AgentEditorView toolbar button (lines 59-73):

```swift
ToolbarItem(placement: .confirmationAction) {
    Button {
        save()
        onSave?()
        dismiss()
    } label: {
        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(.tint, in: Circle())
    }
    .buttonStyle(.glass)
    .disabled(!isValid)
}
```

With the simpler style matching SettingsView:

```swift
ToolbarItem(placement: .confirmationAction) {
    Button {
        save()
        onSave?()
        dismiss()
    } label: {
        Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(isValid ? .blue : .gray)
    }
    .disabled(!isValid)
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add LLMChat/Views/SettingsView.swift LLMChat/Views/AgentEditorView.swift
git commit -m "polish: keyboard dismiss + normalize save button style"
```
