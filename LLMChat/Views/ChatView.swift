import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var modelManager = ModelManager.shared
    let conversation: Conversation
    var onNewChat: (() -> Void)?
    @State private var viewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(conversation: conversation, modelContext: modelContext)
            }
            // Auto-focus keyboard when entering any chat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    ForEach(modelManager.groupedModels) { group in
                        Section(group.displayName) {
                            ForEach(group.models) { model in
                                Button {
                                    conversation.modelId = model.id
                                    try? modelContext.save()
                                } label: {
                                    if model.id == conversation.modelId {
                                        Label(model.name, systemImage: "checkmark")
                                    } else {
                                        Text(model.name)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(modelManager.modelName(for: conversation.modelId))
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.glass)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNewChat?()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func chatContent(viewModel: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sortedMessages) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.sortedMessages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.sortedMessages.count) {
                if let last = viewModel.sortedMessages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar(viewModel: viewModel)
            }
        }
    }

    private var hasText: Bool {
        !(viewModel?.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func inputBar(viewModel: ChatViewModel) -> some View {
        HStack(spacing: 8) {
            TextField("Ask anything", text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ), axis: .vertical)
                .lineLimit(1...6)
                .focused($isInputFocused)

            if viewModel.isStreaming {
                Button {
                    viewModel.stopStreaming()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 30, height: 30)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Button {
                    viewModel.sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(hasText ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 30, height: 30)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!hasText)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 12)
        .background(Color(.systemBackground))
        .background(alignment: .top) {
            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .offset(y: -40)
        }
    }
}
