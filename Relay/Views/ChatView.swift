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
    @State private var showScrollToBottom = false

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
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let distanceFromBottom = geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
                return distanceFromBottom > 200
            } action: { _, isScrolledUp in
                withAnimation(.easeInOut(duration: AppTheme.Motion.standard)) {
                    showScrollToBottom = isScrolledUp
                }
            }
            .onAppear {
                DispatchQueue.main.async { isInputFocused = true }
            }
            .onDisappear(perform: cleanUpIfEmpty)
            .onChange(of: viewModel.sortedMessages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) {
                scrollToBottomInstant(proxy: proxy)
            }
            .overlay(alignment: .bottomTrailing) {
                if showScrollToBottom {
                    Button {
                        scrollToBottom(proxy: proxy)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Memory Request",
            isPresented: Binding(
                get: { viewModel.pendingMemoryApproval != nil },
                set: {
                    if !$0 {
                        viewModel.respondToMemoryApproval(false)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Allow") {
                viewModel.respondToMemoryApproval(true)
            }
            Button("Don't Allow", role: .cancel) {
                viewModel.respondToMemoryApproval(false)
            }
        } message: {
            Text(viewModel.pendingMemoryApproval?.action.message ?? "")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.uiErrorMessage != nil },
                set: { if !$0 { viewModel.uiErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.uiErrorMessage = nil
            }
        } message: {
            Text(viewModel.uiErrorMessage ?? "Something went wrong.")
        }
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
            if !sortedAgents.isEmpty {
                Menu("Agents") {
                    ForEach(sortedAgents) { agent in
                        Button {
                            selectModel(agent.modelId, systemPrompt: agent.systemPrompt)
                        } label: {
                            menuRowLabel(
                                shortLabel(agent.name),
                                icon: agent.iconName ?? "person.circle",
                                isSelected: conversation.modelId == agent.modelId
                            )
                        }
                    }
                }

                if !primaryProviderGroups.isEmpty || !overflowProviderGroups.isEmpty {
                    Divider()
                }
            }

            ForEach(primaryProviderGroups) { group in
                providerGroupMenu(group)
            }

            if !overflowProviderGroups.isEmpty {
                Menu("More...") {
                    ForEach(overflowProviderGroups) { group in
                        providerGroupMenu(group)
                    }
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                Text(shortLabel(modelManager.modelName(for: conversation.modelId)))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 140)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.glass)
    }

    private var sortedAgents: [Agent] {
        agents.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var preferredProviderKeys: [String] {
        ["anthropic", "openai", "google", "x-ai", "meta-llama"]
    }

    private var primaryProviderGroups: [ModelManager.ModelGroup] {
        preferredProviderKeys.compactMap { preferredKey in
            modelManager.groupedModels.first { $0.provider == preferredKey }
        }
    }

    private var overflowProviderGroups: [ModelManager.ModelGroup] {
        modelManager.groupedModels.filter { !preferredProviderKeys.contains($0.provider) }
    }

    private func providerGroupMenu(_ group: ModelManager.ModelGroup) -> some View {
        Menu(group.displayName) {
            ForEach(group.models) { model in
                Button {
                    selectModel(model.id)
                } label: {
                    menuRowLabel(
                        shortLabel(model.name),
                        isSelected: conversation.modelId == model.id
                    )
                }
            }
        }
    }

    private func menuRowLabel(_ title: String, icon: String? = nil, isSelected: Bool = false) -> some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func selectModel(_ modelId: String, systemPrompt: String? = nil) {
        conversation.modelId = modelId
        if let systemPrompt {
            conversation.systemPrompt = systemPrompt
        }
        SettingsManager.sessionModelId = modelId
        if conversation.modelContext != nil {
            do {
                try modelContext.save()
            } catch {
                viewModel.uiErrorMessage = "Couldn't save the selected model. \(error.localizedDescription)"
            }
        }
    }

    private func shortLabel(_ text: String, maxLength: Int = 34) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if let colon = trimmed.lastIndex(of: ":"), colon < trimmed.index(before: trimmed.endIndex) {
            candidate = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        } else if let slash = trimmed.lastIndex(of: "/"), slash < trimmed.index(before: trimmed.endIndex) {
            candidate = String(trimmed[trimmed.index(after: slash)...]).trimmingCharacters(in: .whitespaces)
        } else {
            candidate = trimmed
        }

        guard candidate.count > maxLength else { return candidate }
        return String(candidate.prefix(maxLength - 1)) + "…"
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
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer()
            }
            .padding(.leading, AppTheme.Spacing.xSmall)
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
                        withAnimation(.snappy(duration: AppTheme.Motion.standard)) {
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
        HStack(alignment: .bottom, spacing: 8) {
            attachmentMenu

            HStack(spacing: 8) {
                textField
                trailingButton
            }
            .padding(.leading, 12)
            .padding(.trailing, AppTheme.Spacing.xSmall)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.bubble, style: .continuous)
            )
        }
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
                .frame(width: 42, height: 42)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
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
            .animation(.easeInOut(duration: AppTheme.Motion.quick), value: hasContent)
            .transition(.blurReplace)
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.sortedMessages.last else { return }
        withAnimation(.easeOut(duration: AppTheme.Motion.smooth)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func scrollToBottomInstant(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.sortedMessages.last else { return }
        withAnimation(.linear(duration: 0.08)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func cleanUpIfEmpty() {
        guard conversation.messages.isEmpty, conversation.modelContext != nil else { return }
        modelContext.delete(conversation)
        do {
            try modelContext.save()
        } catch {
            viewModel.uiErrorMessage = "Couldn't clean up empty chat. \(error.localizedDescription)"
        }
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
