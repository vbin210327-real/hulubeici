import SwiftUI

private let chatAccentColor = Color(red: 0.27, green: 0.63, blue: 0.55)
private let assistantAvatarSize: CGFloat = 40

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AIChatMessage] = [
        AIChatMessage(
            role: .system,
            content: """
            你是一名友好的英语词汇学习助手，请使用中文与用户交流，结合上下文提供精炼且实用的建议。只回答与英语学习、词汇、语法、练习或英语相关的内容；如果用户提出无关问题，请礼貌说明你只能提供英语学习方面的帮助。
            """
        ),
        AIChatMessage(
            role: .assistant,
            content: "你好，我是葫芦AI。可以帮你格式化单词、解释单词或者任何和英语有关的问题，随时为你提供帮助。"
        )
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var activeError: IdentifiableError?
    @FocusState private var isInputFocused: Bool
    @State private var generationTask: Task<Void, Never>?
    private let typingIndicatorID = UUID()

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
            .navigationTitle("葫芦AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .onDisappear {
            generationTask?.cancel()
        }
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
                        typingIndicatorView
                            .padding(.horizontal, 16)
                            .padding(.top, visibleMessages.isEmpty ? 18 : 0)
                            .padding(.bottom, 6)
                            .id(typingIndicatorID)
                            .onAppear {
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(typingIndicatorID, anchor: .bottom)
                                    }
                                }
                            }
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
            .onChange(of: isSending) { _, sending in
                guard sending else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(typingIndicatorID, anchor: .bottom)
                    }
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

                if isSending {
                    Button {
                        stopGenerating()
                    } label: {
                        StopSquareIcon()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.27, green: 0.63, blue: 0.55))
                                    .frame(width: 48, height: 48)
                            )
                            .frame(width: 48, height: 48)
                            .accessibilityLabel("停止生成")
                    }
                    .buttonStyle(.plain)
                } else {
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
                    .buttonStyle(.plain)
                    .disabled(!isReadyToSend)
                }
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
        guard !trimmed.isEmpty, !isSending else { return }

        activeError = nil

        let userMessage = AIChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isSending = true

        let conversation = messages
        generationTask?.cancel()
        generationTask = Task {
            do {
                let reply = try await DeepSeekChatService.shared.send(messages: conversation)
                try Task.checkCancellation()
                await MainActor.run {
                    messages.append(reply)
                    isSending = false
                    isInputFocused = false
                    generationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isSending = false
                    activeError = nil
                    generationTask = nil
                }
            } catch let error as URLError where error.code == .cancelled {
                await MainActor.run {
                    isSending = false
                    activeError = nil
                    generationTask = nil
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    activeError = IdentifiableError(message: error.localizedDescription)
                    generationTask = nil
                }
            }
        }
    }

    private func stopGenerating() {
        guard isSending else { return }
        generationTask?.cancel()
        generationTask = nil
        isSending = false
        activeError = nil
        let notice = "已停止生成。"
        if let last = messages.last, last.role == .assistant, last.content.trimmingCharacters(in: .whitespacesAndNewlines) == notice {
            return
        }
        messages.append(AIChatMessage(role: .assistant, content: notice))
    }

    @ViewBuilder
    private func messageBubble(for message: AIChatMessage) -> some View {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = trimmed.isEmpty ? " " : trimmed

        if message.role == .user {
            userMessageView(text: displayText)
        } else {
            assistantMessageView(text: displayText)
        }
    }

    private func userMessageView(text: String) -> some View {
        return HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 48)
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(chatAccentColor)
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var typingIndicatorView: some View {
        TypingIndicatorBubble(avatarSize: assistantAvatarSize)
    }

    private func assistantMessageView(text: String) -> some View {
        let cleaned = sanitizedAssistantText(text)
        return HStack(alignment: .top, spacing: 12) {
            Image("AIAssistantIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: assistantAvatarSize, height: assistantAvatarSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(cleaned)
                    .font(.system(size: 16))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .leading)
            }
            .offset(x: -2)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    private func sanitizedAssistantText(_ original: String) -> String {
        let inlineTokens: [String: String] = [
            "***": "",
            "**": "",
            "__": "",
            "`": "",
            "```": ""
        ]

        var processed = original
        for (token, replacement) in inlineTokens {
            processed = processed.replacingOccurrences(of: token, with: replacement)
        }

        let lines = processed.components(separatedBy: CharacterSet.newlines)
        let bulletPrefixes = ["- ", "* ", "• ", "+ "]

        let cleanedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }

            if trimmed.hasPrefix("### ") {
                return String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            }
            if trimmed.hasPrefix("## ") {
                return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }

            if trimmed.hasPrefix(">") {
                return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            for prefix in bulletPrefixes where trimmed.hasPrefix(prefix) {
                let content = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                return content.isEmpty ? "" : "• \(content)"
            }

            return trimmed
        }

        // Preserve intentional blank lines but collapse multiple empty lines.
        var collapsed: [String] = []
        var previousEmpty = false
        for line in cleanedLines {
            let isEmpty = line.isEmpty
            if isEmpty {
                if !previousEmpty {
                    collapsed.append("")
                }
            } else {
                collapsed.append(line)
            }
            previousEmpty = isEmpty
        }

        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TypingIndicatorBubble: View {
    let avatarSize: CGFloat
    @State private var animate = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("AIAssistantIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: avatarSize, height: avatarSize)

            HStack(spacing: 8) {
                Text("正在输入")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))

                TypingDotsView(isAnimating: $animate)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.52, alignment: .leading)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animate = true
        }
        .onDisappear {
            animate = false
        }
    }
}

private struct TypingDotsView: View {
    @Binding var isAnimating: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
    }
}

private struct StopSquareIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let inset = minSide * 5.25 / 24.0
        let size = minSide - inset * 2
        let cornerRadius = minSide * 2.25 / 24.0
        let roundedRect = CGRect(x: rect.midX - size / 2, y: rect.midY - size / 2, width: size, height: size)
        return Path(roundedRect: roundedRect, cornerRadius: cornerRadius)
    }
}

private struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}
