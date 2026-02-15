import SwiftUI
import SwiftData
import PhotosUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var modelManager = ModelManager.shared
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @FocusState private var isInputFocused: Bool

    let conversation: Conversation
    var onNewChat: (() -> Void)?

    @State private var viewModel: ChatViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    // Cache the UIImage so we're not decoding Data on every frame
    @State private var thumbnailImage: UIImage?

    // MARK: - Init

    init(conversation: Conversation, modelContext: ModelContext, onNewChat: (() -> Void)? = nil) {
        self.conversation = conversation
        self.onNewChat = onNewChat
        _viewModel = State(initialValue: ChatViewModel(conversation: conversation, modelContext: modelContext))
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sortedMessages) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.sortedMessages.last?.id,
                            streamingPhase: viewModel.streamingPhase,
                            isWaitingForToken: viewModel.isWaitingForToken,
                            onRegenerate: { viewModel.regenerateMessage(message) },
                            onEdit: { viewModel.editMessage(message) },
                            onDelete: { viewModel.deleteMessagePair(message) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                DispatchQueue.main.async { isInputFocused = true }
            }
            .onDisappear(perform: cleanUpIfEmpty)
            .onChange(of: viewModel.sortedMessages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) {
                scrollToBottom(proxy: proxy)
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            modelPicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onNewChat?()
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
    }

    private var modelPicker: some View {
        Menu {
            if !agents.isEmpty {
                Section("Agents") {
                    ForEach(agents) { agent in
                        Button {
                            conversation.modelId = agent.modelId
                            conversation.systemPrompt = agent.systemPrompt
                            SettingsManager.sessionModelId = agent.modelId
                            try? modelContext.save()
                        } label: {
                            Label(agent.name, systemImage: agent.iconName ?? "person.circle")
                        }
                    }
                }
            }
            ForEach(modelManager.groupedModels) { group in
                Section(group.displayName) {
                    ForEach(group.models) { model in
                        Button {
                            conversation.modelId = model.id
                            SettingsManager.sessionModelId = model.id
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

    // MARK: - Input bar

    private var hasContent: Bool {
        let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || viewModel.selectedImageData != nil
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            searchChip
            imagePreview
            inputRow
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 12)
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadPhoto(from: newItem)
        }
    }

    // MARK: - Search chip

    @ViewBuilder
    private var searchChip: some View {
        if viewModel.searchEnabled {
            HStack {
                Button {
                    viewModel.searchEnabled = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Search")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer()
            }
            .padding(.leading, 6)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Image preview

    @ViewBuilder
    private var imagePreview: some View {
        if let image = thumbnailImage {
            HStack {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.selectedImageData = nil
                            thumbnailImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .offset(x: 6, y: -6)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    // MARK: - Input row

    private var inputRow: some View {
        HStack(spacing: 8) {
            attachmentMenu
            textField
            trailingButton
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var attachmentMenu: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Select Photos", systemImage: "photo.on.rectangle")
            }
            Toggle(isOn: $viewModel.searchEnabled) {
                Label("Search", systemImage: "magnifyingglass")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    }

    private var textField: some View {
        TextField("Ask anything", text: $viewModel.inputText, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .focused($isInputFocused)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if viewModel.isStreaming {
            Button(action: viewModel.stopStreaming) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 30, height: 30)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .transition(.blurReplace)
        } else {
            Button(action: viewModel.sendMessage) {
                ZStack {
                    Circle()
                        .fill(hasContent ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!hasContent)
            .animation(.easeInOut(duration: 0.15), value: hasContent)
            .transition(.blurReplace)
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.sortedMessages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func cleanUpIfEmpty() {
        guard conversation.messages.isEmpty else { return }
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                viewModel.selectedImageData = data
                // Downscale for the thumbnail so we're not rendering full-res every frame
                thumbnailImage = UIImage(data: data)?
                    .preparingThumbnail(of: CGSize(width: 120, height: 120))
            }
            selectedPhotoItem = nil
        }
    }
}
