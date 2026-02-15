# Settings View Polish & Reorganization

**Date:** 2026-02-14
**Scope:** Moderate restructure of SettingsView.swift

## Toolbar

- **Leading:** Cancel button (X icon) — dismisses without saving
- **Trailing:** Save button (checkmark icon) — dimmed gray when no changes, blue when unsaved changes exist

## Section Order

1. **API Keys** — Merge OpenRouter key + Web Search provider picker + Web Search key into one section. Footer shows provider-specific URL.
2. **Default Model** — Model picker (unchanged)
3. **System Prompt** — TextEditor with footer "Applied to all new chats unless overridden by an agent" (unchanged)
4. **Agents** — Agent list with swipe-to-delete + "New Agent" button (unchanged)
5. **Memories** — Memory list with inline add field (unchanged)
6. **Data** (NEW) — "Clear All Chats" destructive button with confirmation alert

## Consistency Fixes

1. **Save button** — Use simple icon style (current SettingsView pattern) across both SettingsView and AgentEditorView
2. **Section headers** — Normalize to `Section { } header: { Text("Title") }` syntax throughout
3. **Keyboard dismiss** — Add `.scrollDismissesKeyboard(.interactively)` to the Form

## Clear All Chats

- Button styled with `.foregroundColor(.red)`
- On tap, shows `.alert` with "Are you sure?" message
- On confirm, deletes all `Conversation` objects from SwiftData
