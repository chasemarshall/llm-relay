import SwiftUI

struct SFSymbolPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedIcon: String?
    @State private var searchText = ""

    // Curated SF Symbols across categories
    private static let allSymbols = [
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
        if searchText.isEmpty {
            return Self.allSymbols
        }
        return Self.allSymbols.filter { symbol in
            symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 16) {
                ForEach(filtered, id: \.self) { symbol in
                    Button(action: {
                        selectedIcon = symbol
                        dismiss()
                    }) {
                        Image(systemName: symbol)
                            .font(.title2)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selectedIcon == symbol
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.systemGray6)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selectedIcon == symbol
                                            ? Color.accentColor
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search symbols")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedIcon: String? = nil
    SFSymbolPickerView(selectedIcon: $selectedIcon)
}
