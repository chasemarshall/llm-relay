import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    private var isUser: Bool { message.messageRole == .user }
    private var isEmpty: Bool { message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var bubbleColor: Color {
        if message.isError {
            return .red.opacity(0.15)
        }
        return isUser ? .accentColor : Color(.systemGray5)
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

            bubbleContent
                .textSelection(.enabled)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let content = message.content
        let isShort = !content.contains("\n") && content.count < 40

        if isStreaming && !isUser && isEmpty {
            // Thinking state — small circle bubble with pulsing dot
            StreamingIndicator()
                .padding(12)
                .background(bubbleColor, in: Circle())
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
        } else if isStreaming && !isUser {
            // Streaming with content — show text + dots inside bubble
            VStack(alignment: .leading, spacing: 6) {
                Text(MarkdownRenderer.render(content))
                    .foregroundStyle(textColor)
                StreamingIndicator()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(bubbleColor, in: bubbleShape(isShort: false))
        } else {
            Text(MarkdownRenderer.render(content))
                .foregroundStyle(textColor)
                .padding(.horizontal, isShort ? 16 : 14)
                .padding(.vertical, isShort ? 10 : 12)
                .background(bubbleColor, in: bubbleShape(isShort: isShort))
        }
    }

    private func bubbleShape(isShort: Bool) -> some Shape {
        RoundedRectangle(
            cornerRadius: isShort ? 22 : 22,
            style: .continuous
        )
    }
}
