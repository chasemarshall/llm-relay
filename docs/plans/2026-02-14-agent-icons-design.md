# Agent SF Symbol Icons — Design

## Summary

Allow users to assign an SF Symbol icon to each agent. The icon displays in the agents list (settings), the new-chat toolbar menu, and replaces the default `person.circle`.

## Data Model

- Add `iconName: String?` to the `Agent` SwiftData model
- `nil` renders as `"person.circle"` at display time
- No migration needed — SwiftData handles new optional properties

## SFSymbolPickerView (new file)

- Sheet presented from AgentEditorView
- Search bar at top filters symbols by name
- `LazyVGrid` of ~80 curated SF Symbols
- Tapping a symbol selects it and dismisses the sheet
- Currently-selected icon highlighted with a checkmark overlay
- Curated list stored as a `[String]` constant

### Curated Icon Categories

- People: person.circle, person.fill, figure.walk, brain.head.profile, eye, hand.raised
- Tech: cpu, desktopcomputer, laptopcomputer, terminal, server.rack, antenna.radiowaves.left.and.right
- Communication: bubble.left, bubble.right, envelope, phone, megaphone, bell
- Objects: book, pencil, paintbrush, hammer, wrench, scissors, lightbulb
- Nature: leaf, flame, bolt, cloud, moon, sun.max, star
- Shapes/Abstract: circle.hexagongrid, square.grid.2x2, sparkles, wand.and.stars, atom, globe

## Agent Editor Change

- New tappable row at top of form showing current icon + "Choose Icon" label
- Tapping opens SFSymbolPickerView as a sheet

## Display Changes

- **ConversationListView toolbar menu**: `Image(systemName: agent.iconName ?? "person.circle")`
- **SettingsView agents list**: Same — show agent's custom icon next to its name

## Defaults

- No icon selected = `person.circle` (current behavior preserved)
