import SwiftUI

private let chatAccentColor = Color(red: 0.27, green: 0.63, blue: 0.55)

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AIChatMessage] = [
        AIChatMessage(
            role: .system,
            content: """
            你是一名友好的英语词汇学习助手，请使用中文与用户交流，结合上下文提供精炼且实用的建议。
            """
        ),
        AIChatMessage(
            role: .assistant,
            content: "你好，我是词汇学习助手，可以帮你解释单词、造句或者规划学习计划。"
        )
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var activeError: IdentifiableError?
    @FocusState private var isInputFocused: Bool

    private var visibleMessages: [AIChatMessage] {
        messages.filter { $0.role != .system }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatList
                Divider()
                inputBar
            }
            .navigationTitle("AI 学习助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .alert(item: $activeError) { error in
            Alert(
                title: Text("对话失败"),
                message: Text(error.message),
                dismissButton: .default(Text("好的"))
            )
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleMessages) { message in
                        messageBubble(for: message)
                            .padding(.horizontal, 16)
                            .padding(.top, message == visibleMessages.first ? 18 : 0)
                            .id(message.id)
                    }
                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: visibleMessages.last?.id) { _, latest in
                guard let latest else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(latest, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(visibleMessages.last?.id)
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $inputText)
                    .focused($isInputFocused)
                    .frame(minHeight: 36, maxHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        Group {
                            if inputText.isEmpty {
                                Text("请输入问题或想法")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        },
                        alignment: .topLeading
                    )
                    .scrollContentBackground(.hidden)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isReadyToSend ? chatAccentColor : Color.gray.opacity(0.4))
                        )
                }
                .disabled(!isReadyToSend || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    private var isReadyToSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = AIChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isSending = true

        Task {
            do {
                let reply = try await DeepSeekChatService.shared.send(messages: messages)
                await MainActor.run {
                    messages.append(reply)
                    isSending = false
                    isInputFocused = false
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    activeError = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(for message: AIChatMessage) -> some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 32) }

            Text(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 16))
                .foregroundColor(isUser ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? chatAccentColor : Color(.secondarySystemBackground))
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .transition(.opacity.combined(with: .move(edge: isUser ? .trailing : .leading)))
    }
}

private struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}
