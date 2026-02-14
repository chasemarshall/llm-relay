import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    var body: some View {
        HStack {
            if message.messageRole == .user { Spacer(minLength: 60) }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: 4) {
                if message.isError {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(MarkdownRenderer.render(message.content))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if message.messageRole == .user {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.tint.opacity(0.15))
                        }
                    }
                    .foregroundStyle(message.isError ? .red : .primary)

                if isStreaming && message.messageRole == .assistant {
                    StreamingIndicator()
                        .padding(.leading, 14)
                }
            }

            if message.messageRole == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
