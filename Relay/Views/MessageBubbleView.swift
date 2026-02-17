import SwiftUI

// MARK: - Bloom Modifier

struct BloomModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? (phase ? 1.0 : 0.65) : 1.0)
            .onAppear {
                if isActive { startPulse() }
            }
            .onChange(of: isActive) { _, active in
                if active { startPulse() } else { phase = false }
            }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            phase = true
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool
    var streamingPhase: StreamingPhase = .idle
    var isWaitingForToken: Bool = false
    var onRegenerate: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var showThinking = false
    @State private var showSources = false

    private var isUser: Bool { message.messageRole == .user }
    private var isEmpty: Bool { message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasThinking: Bool {
        guard let t = message.thinkingContent else { return false }
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var isThinkingPhase: Bool { isStreaming && !isUser && streamingPhase == .thinking }
    private var isSearchingPhase: Bool { isStreaming && !isUser && streamingPhase == .searching }
    private var hasSources: Bool { !message.searchSources.isEmpty }
    private var hasStats: Bool {
        !isUser && (message.promptTokens != nil || message.durationMs != nil)
    }

    private var bubbleColor: Color {
        if message.isError {
            return .red.opacity(0.15)
        }
        return isUser ? AppTheme.Colors.userBubble : AppTheme.Colors.assistantBubble
    }

    private var textColor: Color {
        if message.isError {
            return .red
        }
        return isUser ? .white : .primary
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                // Search sources disclosure
                if hasSources || isSearchingPhase {
                    searchSection
                }

                // Thinking disclosure
                if hasThinking || isThinkingPhase {
                    thinkingSection
                }

                // Main bubble
                bubbleContent
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        ShareLink(item: message.content) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        if isUser {
                            if let onEdit {
                                Button {
                                    onEdit()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }

                            if let onDelete {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        if !isUser, let onRegenerate {
                            Button {
                                onRegenerate()
                            } label: {
                                Label("Regenerate", systemImage: "arrow.trianglehead.2.counterclockwise")
                            }
                        }

                        if hasStats {
                            Section("Response Stats") {
                                statsContextMenu
                            }
                        }
                    }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Thinking Section

    @ViewBuilder
    private var thinkingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            Button {
                withAnimation(.easeInOut(duration: AppTheme.Motion.standard)) {
                    showThinking.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showThinking ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Thinking")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if showThinking, let thinking = message.thinkingContent, !thinking.isEmpty {
                Text(thinking)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.Colors.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(AppTheme.Colors.subtleBorder.opacity(0.35), lineWidth: AppTheme.Border.hairline)
        }
    }

    // MARK: - Search Section

    @ViewBuilder
    private var searchSection: some View {
        let isActive = isSearchingPhase && !hasSources
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            Button {
                withAnimation(.easeInOut(duration: AppTheme.Motion.standard)) {
                    showSources.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showSources ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(isActive ? "Searching" : "\(message.searchSources.count) Sources")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .modifier(BloomModifier(isActive: isActive))
            }
            .buttonStyle(.plain)

            if showSources {
                let sources = message.searchSources
                if !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sources) { source in
                            Button {
                                if let url = URL(string: source.url) {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(source.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(source.url)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.Colors.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(AppTheme.Colors.subtleBorder.opacity(0.35), lineWidth: AppTheme.Border.hairline)
        }
    }

    // MARK: - Main Bubble

    private var hasImage: Bool { message.imageData != nil }

    @ViewBuilder
    private var imageContent: some View {
        if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let content = message.content
        let isShort = !content.contains("\n") && content.count < 40

        if isStreaming && !isUser && isEmpty && (isThinkingPhase || isSearchingPhase || hasThinking || hasSources) {
            // Handled by disclosure sections above, or transitioning between phases
            EmptyView()
        } else if isStreaming && !isUser && isEmpty {
            // Waiting for first token (no thinking/search context)
            Text("Thinking")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .modifier(BloomModifier(isActive: true))
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, AppTheme.Spacing.small)
                .background(bubbleColor, in: bubbleShape(isShort: true))
        } else if message.isError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote)
                Text(MarkdownRenderer.render(content))
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, isShort ? 16 : 14)
            .padding(.vertical, isShort ? 10 : 12)
            .background(bubbleColor, in: bubbleShape(isShort: isShort))
            .overlay {
                bubbleStroke
            }
        } else if hasImage {
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                imageContent
                if !isEmpty {
                    Text(MarkdownRenderer.render(content))
                        .foregroundStyle(textColor)
                }
            }
            .padding(8)
            .background(bubbleColor, in: bubbleShape(isShort: false))
            .overlay {
                bubbleStroke
            }
        } else if isStreaming && !isUser {
            VStack(alignment: .leading, spacing: 6) {
                Text(MarkdownRenderer.render(content))
                    .foregroundStyle(textColor)
                    .contentTransition(.interpolate)
                    .animation(.easeOut(duration: AppTheme.Motion.quick), value: content)
                if isWaitingForToken {
                    StreamingIndicator()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: AppTheme.Motion.quick), value: isWaitingForToken)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, 12)
            .background(bubbleColor, in: bubbleShape(isShort: false))
            .overlay {
                bubbleStroke
            }
        } else if !isEmpty {
            Text(MarkdownRenderer.render(content))
                .foregroundStyle(textColor)
                .padding(.horizontal, isShort ? 16 : 14)
                .padding(.vertical, isShort ? 10 : 12)
                .background(bubbleColor, in: bubbleShape(isShort: isShort))
                .overlay {
                    bubbleStroke
                }
        }
    }

    @ViewBuilder
    private var bubbleStroke: some View {
        if !isUser && !message.isError {
            RoundedRectangle(cornerRadius: AppTheme.Radius.bubble, style: .continuous)
                .stroke(AppTheme.Colors.subtleBorder.opacity(0.35), lineWidth: AppTheme.Border.hairline)
        }
    }

    // MARK: - Stats Context Menu

    @ViewBuilder
    private var statsContextMenu: some View {
        if let prompt = message.promptTokens, let completion = message.completionTokens {
            Label("\(prompt + completion) tokens (\(prompt) in / \(completion) out)", systemImage: "number")
        } else if let completion = message.completionTokens {
            Label("\(completion) tokens out", systemImage: "number")
        }

        if let latency = message.latencyMs {
            Label("Latency: \(formatMs(latency))", systemImage: "bolt.fill")
        }

        if let duration = message.durationMs {
            Label("Duration: \(formatMs(duration))", systemImage: "timer")
        }

        if let completion = message.completionTokens, let duration = message.durationMs, duration > 0 {
            let tps = Double(completion) / (Double(duration) / 1000.0)
            Label(String(format: "%.1f tok/s", tps), systemImage: "speedometer")
        }
    }

    private func formatMs(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }

    private func bubbleShape(isShort: Bool) -> some Shape {
        RoundedRectangle(
            cornerRadius: AppTheme.Radius.bubble,
            style: .continuous
        )
    }
}
