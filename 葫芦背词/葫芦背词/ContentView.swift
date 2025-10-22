//
//  ContentView.swift
//  葫芦背词
//
//  Created by 林凡滨 on 2025/10/14.
//

import SwiftUI
import Foundation

private let wordsPerPage = 10

final class WordBookStore: ObservableObject {
    @Published private(set) var sections: [WordSection] = []

    private let storageURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        storageURL = directory.appendingPathComponent("wordbook.json")
        load()
    }

    func addSection(_ section: WordSection) {
        sections.append(section)
        save()
    }

    func updateSection(_ section: WordSection) {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[index] = section
        save()
    }

    func updateWords(for sectionID: UUID, words: [WordEntry]) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[index] = sections[index].updatingWords(words)
        save()
    }

    func deleteSection(_ section: WordSection) {
        sections.removeAll { $0.id == section.id }
        save()
    }

    private func load() {
        var loadedFromDisk = false
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([WordSection].self, from: data) {
            sections = decoded
            loadedFromDisk = true
        } else {
            sections = []
        }

        var needsSave = false
        if let bundledSection = try? BundledWordBookLoader.load() {
            if !sections.contains(where: { $0.id == bundledSection.id || $0.title == bundledSection.title }) {
                sections.append(bundledSection)
                needsSave = true
            }
        }

        if sections.isEmpty {
            sections = WordSection.sampleData
            needsSave = true
        }

        if needsSave || !loadedFromDisk {
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sections) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

struct ContentView: View {
    @StateObject private var bookStore = WordBookStore()
    @State private var showingAddSection = false
    @State private var sectionToDelete: WordSection?
    @State private var editingSection: WordSection?
    @StateObject private var hideState = WordVisibilityStore()
    @StateObject private var progressStore = SectionProgressStore()
    @State private var showingAutomationAgent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(bookStore.sections) { section in
                        let studied = studiedWordCount(for: section)
                        let progressState = progressStore.progress(for: section.id)
                        NavigationLink(value: section.id) {
                            SectionCardView(
                                section: section,
                                studiedWords: studied,
                                completedPasses: progressState.completedPasses,
                                onDelete: {
                                    sectionToDelete = section
                                },
                                onEdit: {
                                    editingSection = section
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color(.systemGray6))
            .navigationTitle("葫芦背词")
            .navigationDestination(for: UUID.self) { id in
                if let section = bookStore.sections.first(where: { $0.id == id }) {
                    WordSectionDetailView(
                        section: section,
                        onEdit: { selected in
                            editingSection = selected
                        },
                        onUpdateWords: { sectionID, words in
                            bookStore.updateWords(for: sectionID, words: words)
                        }
                    )
                    .environmentObject(hideState)
                    .environmentObject(progressStore)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAutomationAgent = true
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("批量导入单词")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSection = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("添加词书")
                }
            }
        }
        .sheet(isPresented: $showingAddSection) {
            AddSectionSheet(
                initialSection: nil,
                onSave: { section in
                    bookStore.addSection(section)
                }
            )
            .environmentObject(hideState)
            .environmentObject(progressStore)
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingSection, content: { section in
            AddSectionSheet(initialSection: section) { updatedSection in
                updateSection(updatedSection)
            }
            .environmentObject(hideState)
            .environmentObject(progressStore)
            .presentationDetents([.medium, .large])
        })
        .sheet(isPresented: $showingAutomationAgent) {
            AutomationAgentSheet()
                .environmentObject(bookStore)
                .environmentObject(progressStore)
        }
        .alert("删除词书", isPresented: Binding(
            get: { sectionToDelete != nil },
            set: { newValue in
                if !newValue { sectionToDelete = nil }
            }
        )) {
            Button("取消", role: .cancel) {
                sectionToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let target = sectionToDelete {
                    hideState.remove(entries: target.words)
                    progressStore.resetProgress(for: target.id)
                    bookStore.deleteSection(target)
                }
                sectionToDelete = nil
            }
        } message: {
            Text("删除后将无法恢复，确认删除？")
        }
    }

    private func updateSection(_ section: WordSection) {
        if let previous = bookStore.sections.first(where: { $0.id == section.id }) {
            hideState.reconcile(previous: previous, updated: section)
        }
        bookStore.updateSection(section)
        if let updated = bookStore.sections.first(where: { $0.id == section.id }) {
            let totalPages = max(updated.words.chunked(into: wordsPerPage).count, 1)
            progressStore.clampProgress(for: updated.id, totalPages: totalPages, targetPasses: updated.targetPasses)
        }
        editingSection = nil
    }

    private func studiedWordCount(for section: WordSection) -> Int {
        let totalWords = section.words.count
        guard totalWords > 0 else { return 0 }
        let totalPages = max(1, (totalWords + wordsPerPage - 1) / wordsPerPage)
        let completedPages = max(0, min(progressStore.completedPages(for: section.id), totalPages))
        let estimatedWords = completedPages * wordsPerPage
        return min(estimatedWords, totalWords)
    }
}

private struct SectionCardView: View {
    let section: WordSection
    let studiedWords: Int
    let completedPasses: Int
    let onDelete: () -> Void
    let onEdit: () -> Void

    private var normalizedPassCount: Int {
        let target = max(section.targetPasses, 1)
        return min(max(completedPasses, 0), target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if section.targetPasses > 1 {
                    Text("目标遍数 ×\(section.targetPasses)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label("\(section.words.count)/\(studiedWords)", systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(section.targetPasses)/\(normalizedPassCount)", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.blue)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                )
                .accessibilityLabel("编辑词书")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(
                    Circle()
                        .fill(Color.red.opacity(0.1))
                )
                .accessibilityLabel("删除词书")
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

private struct WordRowView: View {
    let entry: WordEntry
    @EnvironmentObject private var hideState: WordVisibilityStore

    var body: some View {
        let wordVisible = hideState.isWordVisible(entry.id)
        let meaningVisible = hideState.isMeaningVisible(entry.id)

        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(entry.word)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)
                .opacity(wordVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: wordVisible)
                .overlay {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hideState.toggleWord(id: entry.id)
                            }
                        }
                }

            Text(entry.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(meaningVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: meaningVisible)
                .overlay {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hideState.toggleMeaning(id: entry.id)
                            }
                        }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct WordSectionDetailView: View {
    let section: WordSection
    let onEdit: ((WordSection) -> Void)?
    let onUpdateWords: (UUID, [WordEntry]) -> Void

    @EnvironmentObject private var hideState: WordVisibilityStore
    @EnvironmentObject private var progressStore: SectionProgressStore
    init(section: WordSection, onEdit: ((WordSection) -> Void)? = nil, onUpdateWords: @escaping (UUID, [WordEntry]) -> Void) {
        self.section = section
        self.onEdit = onEdit
        self.onUpdateWords = onUpdateWords
        _pageEntries = State(initialValue: section.words.chunked(into: wordsPerPage))
    }

    @State private var pageEntries: [[WordEntry]]
    @State private var currentPage: Int = 0
    @State private var didLoadInitialPage = false
    @State private var activeDialAction: GlassDialAction?

    private var progressState: SectionProgressStore.ProgressState {
        progressStore.progress(for: section.id)
    }

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pageEntries.enumerated()), id: \.offset) { index, entries in
                WordPageView(entries: entries)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    .tag(index)
            }
        }
        .background(Color(.systemGray6))
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onEdit(section)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            VStack(spacing: 10) {
                if let action = activeDialAction {
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(action.highlightColor)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
                GlassDial(actions: glassDialActions, size: 168) { action in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        activeDialAction = action
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .onAppear {
            activeDialAction = nil
            guard !didLoadInitialPage else { return }
            progressStore.clampProgress(for: section.id, totalPages: pageEntries.count, targetPasses: section.targetPasses)
            let nextPage = progressStore.nextPageIndex(for: section.id, totalPages: pageEntries.count, targetPasses: section.targetPasses)
            currentPage = min(nextPage, max(pageEntries.count - 1, 0))
            enforceForwardOnlyNavigation(for: currentPage)
            didLoadInitialPage = true
        }
        .onChange(of: section.id) { _, _ in
            didLoadInitialPage = false
            activeDialAction = nil
        }
        .onChange(of: section.words) { _, newWords in
            let pages = newWords.chunked(into: wordsPerPage)
            pageEntries = pages
            progressStore.clampProgress(for: section.id, totalPages: pages.count, targetPasses: section.targetPasses)
            currentPage = min(currentPage, max(pages.count - 1, 0))
            activeDialAction = nil
            enforceForwardOnlyNavigation(for: currentPage)
        }
        .onChange(of: currentPage) { _, newValue in
            enforceForwardOnlyNavigation(for: newValue)
        }
    }

    private var glassDialActions: [GlassDialAction] {
        let total = max(pageEntries.count, 1)
        let targetReached = progressState.completedPasses >= section.targetPasses && progressState.completedPages >= total
        let canMark = pageEntries.indices.contains(currentPage) && !targetReached
        let canShuffle = pageEntries.indices.contains(currentPage) && pageEntries[currentPage].count > 1
        let entries = currentPageEntries
        let allMeaningsVisible = hideState.areAllMeaningsVisible(for: entries)
        let canToggleMeanings = !entries.isEmpty

        return [
            GlassDialAction(
                slot: .leading,
                systemImage: "shuffle",
                title: "打乱顺序",
                highlightColor: Color(red: 0.68, green: 0.48, blue: 0.98),
                isEnabled: canShuffle,
                handler: shuffleCurrentPage
            ),
            GlassDialAction(
                slot: .trailing,
                systemImage: allMeaningsVisible ? "eye.slash" : "eye",
                title: allMeaningsVisible ? "隐藏释义" : "显示释义",
                highlightColor: Color(red: 1.0, green: 0.62, blue: 0.34),
                isEnabled: canToggleMeanings,
                handler: toggleCurrentPageMeaningsVisibility
            ),
            GlassDialAction(
                slot: .bottom,
                systemImage: "checkmark.circle",
                title: "完成并继续",
                highlightColor: Color(red: 0.36, green: 0.82, blue: 0.64),
                isEnabled: canMark,
                handler: markCurrentPageCompleted
            )
        ]
    }

    private func markCurrentPageCompleted() {
        guard pageEntries.indices.contains(currentPage) else { return }
        let total = pageEntries.count
        let state = progressStore.markPageCompleted(sectionID: section.id, totalPages: total, pageIndex: currentPage, targetPasses: section.targetPasses)
        let targetPage = min(state.completedPages, max(total - 1, 0))
        if currentPage != targetPage {
            withAnimation(.easeInOut) {
                currentPage = targetPage
            }
        }
    }

    private func shuffleCurrentPage() {
        guard pageEntries.indices.contains(currentPage) else { return }
        withAnimation(.easeInOut) {
            pageEntries[currentPage].shuffle()
        }
        let flattened = pageEntries.flatMap { $0 }
        onUpdateWords(section.id, flattened)
    }

    private var currentPageEntries: [WordEntry] {
        guard pageEntries.indices.contains(currentPage) else { return [] }
        return pageEntries[currentPage]
    }

    private func enforceForwardOnlyNavigation(for requestedPage: Int) {
        let total = pageEntries.count
        guard total > 0 else { return }
        let completed = progressStore.completedPages(for: section.id)
        let minAllowed = min(completed, max(total - 1, 0))
        guard requestedPage >= minAllowed else {
            withAnimation(.easeInOut) {
                currentPage = minAllowed
            }
            return
        }
    }

    private func toggleCurrentPageMeaningsVisibility() {
        let entries = currentPageEntries
        guard !entries.isEmpty else { return }
        let allVisible = hideState.areAllMeaningsVisible(for: entries)
        hideState.setMeaningVisibility(visible: !allVisible, for: entries)
    }
}

private struct WordPageView: View {
    let entries: [WordEntry]
    @EnvironmentObject private var hideState: WordVisibilityStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(entries) { entry in
                    WordRowView(entry: entry)
                        .environmentObject(hideState)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct GlassDialAction: Identifiable {
    enum Slot: Hashable {
        case leading
        case trailing
        case top
        case bottom
    }

    let slot: Slot
    let systemImage: String
    let title: String
    let highlightColor: Color
    let isEnabled: Bool
    let handler: () -> Void

    var id: Slot { slot }
}

private struct GlassDial: View {
    let actions: [GlassDialAction]
    let size: CGFloat
    let onActiveChange: (GlassDialAction?) -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var dragOffset: CGSize = .zero
    @State private var activeSlot: GlassDialAction.Slot?

    init(actions: [GlassDialAction], size: CGFloat, onActiveChange: @escaping (GlassDialAction?) -> Void = { _ in }) {
        self.actions = actions
        self.size = size
        self.onActiveChange = onActiveChange
    }

    private var leadingAction: GlassDialAction? {
        actions.first { $0.slot == .leading }
    }

    private var trailingAction: GlassDialAction? {
        actions.first { $0.slot == .trailing }
    }

    private var topAction: GlassDialAction? {
        actions.first { $0.slot == .top }
    }

    private var bottomAction: GlassDialAction? {
        actions.first { $0.slot == .bottom }
    }

    private var activeAction: GlassDialAction? {
        guard let activeSlot else { return nil }
        return actions.first { $0.slot == activeSlot }
    }

    var body: some View {
        ZStack {
            if voiceOverEnabled {
                VStack(spacing: 12) {
                    ForEach(actions) { action in
                        Button {
                            action.handler()
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!action.isEnabled)
                    }
                }
                .padding(.horizontal, 16)
                .onAppear {
                    onActiveChange(nil)
                }
            } else {
                dialView
            }
        }
        .frame(height: voiceOverEnabled ? nil : size)
    }

    private var dialView: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = diameter / 2
            let clampedOffset = clamp(dragOffset, radius: radius * 0.68)
            let coreSize = radius * 0.5
            let hollowDiameter = diameter * 0.7
            let hollowLineWidth = radius * 0.2
            let activeGlow = (activeAction?.highlightColor ?? Color.white).opacity(0.7)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 6)
                            .blur(radius: 8)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.76),
                                        Color.white.opacity(0.28)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .blur(radius: radius * 0.45)
                    )
                    .shadow(color: Color.white.opacity(0.32), radius: radius * 0.2, x: -radius * 0.12, y: -radius * 0.16)
                    .shadow(color: Color.black.opacity(0.16), radius: radius * 0.32, x: 0, y: radius * 0.22)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: hollowLineWidth
                    )
                    .frame(width: hollowDiameter, height: hollowDiameter)
                    .overlay(
                        Circle()
                            .stroke(activeGlow, lineWidth: 4.5)
                            .blur(radius: 3.6)
                            .opacity(activeSlot == nil ? 0 : 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                            .frame(width: hollowDiameter + hollowLineWidth * 0.32, height: hollowDiameter + hollowLineWidth * 0.32)
                            .blendMode(.plusLighter)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: radius * 0.12, x: 0, y: radius * 0.1)

                if let action = leadingAction {
                    slotView(for: action, radius: radius, isActive: activeSlot == .leading)
                        .offset(x: -radius * 0.6, y: -radius * 0.5)
                }

                if let action = trailingAction {
                    slotView(for: action, radius: radius, isActive: activeSlot == .trailing)
                        .offset(x: radius * 0.6, y: -radius * 0.5)
                }

                if let action = topAction {
                    slotView(for: action, radius: radius, isActive: activeSlot == .top)
                        .offset(y: -radius * 0.75)
                }

                if let action = bottomAction {
                    slotView(for: action, radius: radius, isActive: activeSlot == .bottom)
                        .offset(y: radius * 0.75)
                }

                liquidCore(size: coreSize, offset: clampedOffset, tint: activeAction?.highlightColor)
                    .frame(width: coreSize, height: coreSize)
                    .offset(clampedOffset)
                    .gesture(dragGesture(radius: radius))
                    .animation(.easeOut(duration: 0.18), value: clampedOffset)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 3)
                            .blur(radius: 4)
                            .offset(clampedOffset)
                            .opacity(0.75)
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: size)
        .padding(.horizontal, 18)
    }

    private func slotView(for action: GlassDialAction, radius: CGFloat, isActive: Bool) -> some View {
        let baseSize = radius * 0.58
        let isActiveAndEnabled = isActive && action.isEnabled
        return ZStack {
            Circle()
                .fill(Color.white.opacity(action.isEnabled ? 0.16 : 0.08))
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Circle()
                        .stroke(action.isEnabled ? Color.white.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1.1)
                )
                .overlay(
                    Circle()
                        .fill(action.highlightColor.opacity(0.45))
                        .blur(radius: baseSize * 0.5)
                        .opacity(isActiveAndEnabled ? 1 : 0)
                        .scaleEffect(isActiveAndEnabled ? 1.05 : 0.9)
                )
                .overlay(
                    Circle()
                        .stroke(action.highlightColor.opacity(0.65), lineWidth: isActiveAndEnabled ? 2.4 : 0)
                        .blur(radius: 2.6)
                        .opacity(isActiveAndEnabled ? 1 : 0)
                )
                .shadow(color: action.highlightColor.opacity(isActiveAndEnabled ? 0.35 : 0.18), radius: baseSize * (isActiveAndEnabled ? 0.55 : 0.24), x: 0, y: baseSize * (isActiveAndEnabled ? 0.28 : 0.16))
                .shadow(color: Color.black.opacity(0.16), radius: baseSize * 0.34, x: 0, y: baseSize * 0.2)

            Image(systemName: action.systemImage)
                .font(.system(size: action.isEnabled ? 20 : 18, weight: .semibold))
                .foregroundStyle(action.isEnabled ? Color.white : Color.white.opacity(0.45))
                .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 3)
                .scaleEffect(isActiveAndEnabled ? 1.08 : (action.isEnabled ? 1.0 : 0.96))
        }
        .frame(width: baseSize, height: baseSize)
        .scaleEffect(isActiveAndEnabled ? 1.09 : (action.isEnabled ? 1.0 : 0.95))
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isActiveAndEnabled)
    }

    private func liquidCore(size: CGFloat, offset: CGSize, tint: Color?) -> some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotationProgress = time.truncatingRemainder(dividingBy: 6.0) / 6.0
            let shimmer = CGFloat(sin(time * 1.4)) * size * 0.12
            let highlightOffset = CGSize(
                width: -size * 0.24 + shimmer * 0.35,
                height: -size * 0.28 + shimmer * 0.1
            )
            let causticShift = CGSize(width: -offset.width * 0.1, height: -offset.height * 0.1)

            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.87, green: 0.98, blue: 1.0),
                            Color(red: 0.99, green: 0.81, blue: 0.97),
                            Color(red: 0.82, green: 0.95, blue: 0.86),
                            Color(red: 0.92, green: 0.89, blue: 1.0),
                            Color(red: 0.87, green: 0.98, blue: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(rotationProgress * 360),
                        endAngle: .degrees(rotationProgress * 360 + 360)
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.2),
                                    .clear
                                ]),
                                center: .init(x: 0.25, y: 0.2),
                                startRadius: 0,
                                endRadius: size * 0.7
                            )
                        )
                        .blur(radius: size * 0.22)
                        .offset(highlightOffset)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1.3)
                        .blendMode(.plusLighter)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.6
                        )
                        .blur(radius: 3.4)
                        .opacity(0.7)
                )
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .mask(
                            Circle()
                                .offset(x: causticShift.width, y: causticShift.height)
                                .blur(radius: size * 0.24)
                        )
                )
                .shadow(color: Color.white.opacity(0.32), radius: size * 0.18, x: -size * 0.12, y: -size * 0.18)
                .shadow(color: Color.black.opacity(0.18), radius: size * 0.3, x: 0, y: size * 0.18)
                .overlay {
                    if let tintColor = tint {
                        Circle()
                            .fill(tintColor.opacity(0.4))
                            .blur(radius: size * 0.45)
                            .scaleEffect(1.35)
                    }
                }
        }
    }

    private func dragGesture(radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let translation = value.translation
                dragOffset = translation
                let potential = determineSlot(for: translation, radius: radius)
                if let slot = potential, let action = actions.first(where: { $0.slot == slot }) {
                    activeSlot = slot
                    onActiveChange(action)
                } else {
                    activeSlot = nil
                    onActiveChange(nil)
                }
            }
            .onEnded { value in
                let translation = value.translation
                let potential = determineSlot(for: translation, radius: radius)
                let selectedSlot = actions.contains(where: { $0.slot == potential }) ? potential : nil
                let action = actions.first { $0.slot == selectedSlot }
                dragOffset = .zero
                activeSlot = nil
                onActiveChange(nil)
                if let action = action, action.isEnabled {
                    action.handler()
                }
            }
    }

    private func determineSlot(for translation: CGSize, radius: CGFloat) -> GlassDialAction.Slot? {
        let threshold = radius * 0.32
        let distance = hypot(translation.width, translation.height)
        guard distance > threshold else { return nil }
        if translation.height > threshold {
            return .bottom
        }
        if translation.height < -threshold {
            if translation.width >= 0 {
                return .trailing
            } else {
                return .leading
            }
        }
        if translation.width < -threshold * 0.6 {
            return .leading
        }
        if translation.width > threshold * 0.6 {
            return .trailing
        }
        return nil
    }

    private func clamp(_ offset: CGSize, radius: CGFloat) -> CGSize {
        let distance = hypot(offset.width, offset.height)
        guard distance > radius, distance > 0 else {
            return offset
        }
        let scale = radius / distance
        return CGSize(width: offset.width * scale, height: offset.height * scale)
    }
}

private struct AddSectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var subtitle: String
    @State private var entries: [AddEntry]
    @State private var errorMessage: String?
    @State private var targetPasses: Int
    @State private var searchText: String

    let initialSection: WordSection?
    let onSave: (WordSection) -> Void

    init(initialSection: WordSection?, onSave: @escaping (WordSection) -> Void) {
        self.initialSection = initialSection
        self.onSave = onSave

        if let section = initialSection {
            _title = State(initialValue: section.title)
            _subtitle = State(initialValue: section.subtitle ?? "")
            let mappedEntries = section.words.map { AddEntry(id: $0.id, word: $0.word, meaning: $0.meaning) }
            _entries = State(initialValue: mappedEntries.isEmpty ? [AddEntry()] : mappedEntries)
            _targetPasses = State(initialValue: max(section.targetPasses, 1))
            _searchText = State(initialValue: "")
        } else {
            _title = State(initialValue: "")
            _subtitle = State(initialValue: "")
            _entries = State(initialValue: [AddEntry()])
            _targetPasses = State(initialValue: 1)
            _searchText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section("基本信息") {
                        TextField("词书名称", text: $title)
                        TextField("补充信息（选填）", text: $subtitle)
                        Stepper {
                            Text("目标遍数：\(targetPasses)")
                        } onIncrement: {
                            targetPasses += 1
                        } onDecrement: {
                            targetPasses = max(1, targetPasses - 1)
                        }
                    }

                    Section("单词列表") {
                        TextField("搜索单词", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        let filteredEntries = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? entries
                            : entries.filter { $0.word.localizedCaseInsensitiveContains(searchText) }

                        if filteredEntries.isEmpty {
                            ContentUnavailableView("未找到匹配的单词", systemImage: "magnifyingglass")
                        }

                        ForEach(filteredEntries, id: \.id) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("单词", text: binding(for: entry.id, keyPath: \.word))
                                    .textInputAutocapitalization(.never)
                                TextField("释义", text: binding(for: entry.id, keyPath: \.meaning))
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(.vertical, 6)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeEntry(withID: entry.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }

                        Button {
                            let newEntry = AddEntry()
                            entries.append(newEntry)
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo(newEntry.id, anchor: .bottom)
                                }
                            }
                        } label: {
                            Label("添加单词", systemImage: "plus.circle")
                        }
                    }
                }
                .navigationTitle(initialSection == nil ? "添加自定义词书" : "编辑词书")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveSection()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .alert(errorMessage ?? "", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { _ in errorMessage = nil }
                )) {
                    Button("好的", role: .cancel) {}
                }
            }
        }
    }

    private func saveSection() {
        let parsedEntries = entries
            .compactMap { entry -> WordEntry? in
                let trimmedWord = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedMeaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedWord.isEmpty else { return nil }
                return WordEntry(id: entry.id, word: trimmedWord, meaning: trimmedMeaning)
            }

        guard !parsedEntries.isEmpty else {
            errorMessage = "至少需要输入一个单词。"
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let newSection = WordSection(
            id: initialSection?.id ?? UUID(),
            title: trimmedTitle,
            subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle,
            words: parsedEntries,
            targetPasses: targetPasses
        )

        onSave(newSection)
        dismiss()
    }

    private func removeEntry(withID id: UUID) {
        entries.removeAll { $0.id == id }
        if entries.isEmpty {
            entries.append(AddEntry())
        }
    }

    private func binding<Value>(for id: UUID, keyPath: WritableKeyPath<AddEntry, Value>) -> Binding<Value> {
        Binding(
            get: {
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    return entries[index][keyPath: keyPath]
                }
                let fallback = AddEntry()[keyPath: keyPath]
                return fallback
            },
            set: { newValue in
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index][keyPath: keyPath] = newValue
                }
            }
        )
    }
}

private struct AutomationAgentSheet: View {
    @EnvironmentObject private var bookStore: WordBookStore
    @EnvironmentObject private var progressStore: SectionProgressStore
    @Environment(\.dismiss) private var dismiss

    @State private var rawInput: String = ""
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private struct ParsedEntry {
        let book: String
        let word: String
        let meaning: String
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("按照 “词书名称|单词|释义” 的格式逐行粘贴内容，示例：\n高中词汇|abandon|v. 放弃\n雅思词汇|accommodate|v. 容纳")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if rawInput.isEmpty {
                        Text("词书名称|单词|释义")
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.horizontal, 6)
                    }
                    TextEditor(text: $rawInput)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                }

        if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(Color.green)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.orange)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("批量导入单词")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        processInput()
                    } label: {
                        Text(isProcessing ? "处理中…" : "开始导入")
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    private func processInput() {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入需要导入的单词。"
            resultMessage = nil
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let lines = trimmed.components(separatedBy: .newlines)
        var parsedEntries: [ParsedEntry] = []
        var invalidLines: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let components = line.components(separatedBy: "|")
            guard components.count >= 3 else {
                invalidLines.append(rawLine)
                continue
            }
            let book = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let word = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = components.dropFirst(2).joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)

            guard !book.isEmpty, !word.isEmpty else {
                invalidLines.append(rawLine)
                continue
            }

            parsedEntries.append(ParsedEntry(book: book, word: word, meaning: meaning.isEmpty ? "-" : meaning))
        }

        guard !parsedEntries.isEmpty else {
            errorMessage = "没有可导入的单词，请检查格式。"
            resultMessage = nil
            return
        }

        var groupedEntries: [String: [ParsedEntry]] = [:]
        for entry in parsedEntries {
            groupedEntries[entry.book, default: []].append(entry)
        }

        var totalAdded = 0
        var touchedBooks: Set<String> = []

        for (bookTitle, entries) in groupedEntries {
            let normalizedTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTitle.isEmpty else { continue }

            if let index = bookStore.sections.firstIndex(where: { $0.title.compare(normalizedTitle, options: .caseInsensitive) == .orderedSame }) {
                let existing = bookStore.sections[index]
                var existingWords = Set(existing.words.map { $0.word.lowercased() })
                var newEntries: [WordEntry] = []

                for item in entries {
                    let lower = item.word.lowercased()
                    if existingWords.contains(lower) { continue }
                    let entry = WordEntry(word: item.word, meaning: item.meaning)
                    newEntries.append(entry)
                    existingWords.insert(lower)
                }

                guard !newEntries.isEmpty else { continue }

                var mergedWords = existing.words
                mergedWords.append(contentsOf: newEntries)
                let updatedSection = WordSection(
                    id: existing.id,
                    title: existing.title,
                    subtitle: existing.subtitle,
                    words: mergedWords,
                    targetPasses: existing.targetPasses
                )

                bookStore.updateSection(updatedSection)
                let totalPages = max(mergedWords.chunked(into: wordsPerPage).count, 1)
                progressStore.clampProgress(for: updatedSection.id, totalPages: totalPages, targetPasses: updatedSection.targetPasses)
                totalAdded += newEntries.count
                touchedBooks.insert(existing.title)
            } else {
                let newWords = entries.map { WordEntry(word: $0.word, meaning: $0.meaning) }
                guard !newWords.isEmpty else { continue }
                let newSection = WordSection(
                    title: normalizedTitle,
                    subtitle: nil,
                    words: newWords,
                    targetPasses: 1
                )
                bookStore.addSection(newSection)
                let totalPages = max(newWords.chunked(into: wordsPerPage).count, 1)
                progressStore.clampProgress(for: newSection.id, totalPages: totalPages, targetPasses: newSection.targetPasses)
                totalAdded += newWords.count
                touchedBooks.insert(newSection.title)
            }
        }

        if totalAdded > 0 {
            resultMessage = "已向 \(touchedBooks.count) 个词书添加 \(totalAdded) 个单词。"
        } else {
            resultMessage = "没有新单词被导入（可能与现有词条重复）。"
        }

        if invalidLines.isEmpty {
            errorMessage = nil
        } else {
            let preview = invalidLines.prefix(3).joined(separator: "；")
            errorMessage = "以下行无法解析：\(preview)\(invalidLines.count > 3 ? " 等" : "")"
        }
    }
}

struct WordEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let word: String
    let meaning: String

    init(id: UUID = UUID(), word: String, meaning: String) {
        self.id = id
        self.word = word
        self.meaning = meaning
    }

    static func == (lhs: WordEntry, rhs: WordEntry) -> Bool {
        lhs.id == rhs.id && lhs.word == rhs.word && lhs.meaning == rhs.meaning
    }
}

struct WordSection: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String?
    let words: [WordEntry]
    let targetPasses: Int

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, words, targetPasses
    }

    fileprivate init(id: UUID = UUID(), title: String, subtitle: String? = nil, words: [WordEntry], targetPasses: Int = 1) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.words = words
        self.targetPasses = max(targetPasses, 1)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        words = try container.decode([WordEntry].self, forKey: .words)
        targetPasses = try container.decodeIfPresent(Int.self, forKey: .targetPasses) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(words, forKey: .words)
        try container.encode(targetPasses, forKey: .targetPasses)
    }

    func updatingWords(_ newWords: [WordEntry]) -> WordSection {
        WordSection(id: id, title: title, subtitle: subtitle, words: newWords, targetPasses: targetPasses)
    }
}

final class SectionProgressStore: ObservableObject {
    struct ProgressState: Codable, Equatable {
        var completedPages: Int = 0
        var completedPasses: Int = 0
    }

    @Published private var progressStates: [UUID: ProgressState] = [:] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let defaultsKey = "SectionProgressStore.v1"
    private var isRestoring = false

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        if let data = userDefaults.data(forKey: defaultsKey) {
            if let decoded = try? JSONDecoder().decode([UUID: ProgressState].self, from: data) {
                isRestoring = true
                progressStates = decoded
                isRestoring = false
            } else if let legacy = try? JSONDecoder().decode([UUID: Int].self, from: data) {
                isRestoring = true
                progressStates = legacy.reduce(into: [:]) { result, element in
                    result[element.key] = ProgressState(completedPages: element.value, completedPasses: 0)
                }
                isRestoring = false
            }
        }
    }

    func progress(for sectionID: UUID) -> ProgressState {
        progressStates[sectionID] ?? ProgressState()
    }

    func completedPages(for sectionID: UUID) -> Int {
        max(0, min(progress(for: sectionID).completedPages, Int.max))
    }

    func completedPasses(for sectionID: UUID) -> Int {
        max(0, progress(for: sectionID).completedPasses)
    }

    func nextPageIndex(for sectionID: UUID, totalPages: Int, targetPasses: Int) -> Int {
        guard totalPages > 0 else { return 0 }
        let state = progress(for: sectionID)
        let target = max(1, targetPasses)
        if state.completedPasses >= target {
            return max(totalPages - 1, 0)
        }
        return min(state.completedPages, max(totalPages - 1, 0))
    }

    @discardableResult
    func markPageCompleted(sectionID: UUID, totalPages: Int, pageIndex: Int, targetPasses: Int) -> ProgressState {
        guard totalPages > 0 else { return progress(for: sectionID) }
        var state = progress(for: sectionID)
        let target = max(1, targetPasses)
        if state.completedPasses >= target && state.completedPages >= totalPages {
            return state
        }

        let nextPage = pageIndex + 1
        if nextPage >= totalPages {
            if state.completedPasses + 1 >= target {
                state.completedPasses = min(state.completedPasses + 1, target)
                state.completedPages = totalPages
            } else {
                state.completedPasses += 1
                state.completedPages = 0
            }
        } else {
            state.completedPages = max(state.completedPages, nextPage)
        }

        progressStates[sectionID] = state
        return state
    }

    fileprivate func clampProgress(for sectionID: UUID, totalPages: Int, targetPasses: Int) {
        var state = progress(for: sectionID)
        let target = max(1, targetPasses)
        state.completedPasses = min(state.completedPasses, target)

        if totalPages <= 0 {
            state.completedPages = 0
        } else {
            state.completedPages = min(state.completedPages, totalPages)
            if state.completedPasses >= target {
                state.completedPages = totalPages
            }
        }

        progressStates[sectionID] = state
    }

    func resetProgress(for sectionID: UUID) {
        progressStates.removeValue(forKey: sectionID)
    }

    private func persist() {
        guard !isRestoring,
              let data = try? JSONEncoder().encode(progressStates) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}

final class WordVisibilityStore: ObservableObject {
    @Published private var visibility: [UUID: EntryVisibility] = [:] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let defaultsKey = "WordVisibilityStore.v1"
    private var isRestoring = false

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([UUID: EntryVisibility].self, from: data) {
            isRestoring = true
            visibility = decoded
            isRestoring = false
        }
    }

    func isWordVisible(_ id: UUID) -> Bool {
        visibility[id]?.showWord ?? true
    }

    func isMeaningVisible(_ id: UUID) -> Bool {
        visibility[id]?.showMeaning ?? true
    }

    func toggleWord(id: UUID) {
        var entry = visibility[id] ?? EntryVisibility()
        entry.showWord.toggle()
        if entry.showWord && entry.showMeaning {
            visibility.removeValue(forKey: id)
        } else {
            visibility[id] = entry
        }
    }

    func toggleMeaning(id: UUID) {
        var entry = visibility[id] ?? EntryVisibility()
        entry.showMeaning.toggle()
        if entry.showWord && entry.showMeaning {
            visibility.removeValue(forKey: id)
        } else {
            visibility[id] = entry
        }
    }

    func areAllMeaningsVisible(for entries: [WordEntry]) -> Bool {
        entries.allSatisfy { isMeaningVisible($0.id) }
    }

    func setMeaningVisibility(visible: Bool, for entries: [WordEntry]) {
        guard !entries.isEmpty else { return }
        var newVisibility = visibility
        var didChange = false
        for entry in entries {
            let currentValue = newVisibility[entry.id] ?? EntryVisibility()
            var updatedValue = currentValue
            updatedValue.showMeaning = visible
            if updatedValue.showWord && updatedValue.showMeaning {
                if newVisibility.removeValue(forKey: entry.id) != nil {
                    didChange = true
                }
            } else {
                if newVisibility[entry.id] != updatedValue {
                    newVisibility[entry.id] = updatedValue
                    didChange = true
                }
            }
        }
        if didChange {
            visibility = newVisibility
        }
    }

    fileprivate func remove(entries: [WordEntry]) {
        guard !entries.isEmpty else { return }
        var newVisibility = visibility
        var didChange = false
        for entry in entries {
            if newVisibility.removeValue(forKey: entry.id) != nil {
                didChange = true
            }
        }
        if didChange {
            visibility = newVisibility
        }
    }

    fileprivate func reconcile(previous: WordSection, updated: WordSection) {
        let updatedIDs = Set(updated.words.map(\.id))
        var newVisibility = visibility
        var didChange = false
        for word in previous.words where !updatedIDs.contains(word.id) {
            if newVisibility.removeValue(forKey: word.id) != nil {
                didChange = true
            }
        }
        if didChange {
            visibility = newVisibility
        }
    }

    private func persist() {
        guard !isRestoring else { return }
        if let data = try? JSONEncoder().encode(visibility) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    struct EntryVisibility: Codable, Equatable {
        var showWord: Bool = true
        var showMeaning: Bool = true
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [Array(self)] }
        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}

private struct AddEntry: Identifiable, Equatable {
    let id: UUID
    var word: String
    var meaning: String

    init(id: UUID = UUID(), word: String = "", meaning: String = "") {
        self.id = id
        self.word = word
        self.meaning = meaning
    }
}

private enum BundledWordBookLoader {
    private enum LoaderError: Error {
        case resourceMissing
        case noEntries
    }

    private static let resourceName = "highschool3500_shuffled"
    private static let resourceExtension = "txt"

    private static let sectionID = UUID(uuidString: "095D66A2-6E17-42A3-B0FA-9022D3AD4398")!

    static func load() throws -> WordSection {
        let candidateURLs: [URL?] = [
            Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
            Bundle.main.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Resources"),
            Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).\(resourceExtension)"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/\(resourceName).\(resourceExtension)")
        ]
        guard let url = candidateURLs.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw LoaderError.resourceMissing
        }
        let rawContent = try String(contentsOf: url, encoding: .utf8)
        let entries = rawContent
            .split(whereSeparator: \.isNewline)
            .compactMap { makeEntry(from: String($0)) }
        guard !entries.isEmpty else {
            throw LoaderError.noEntries
        }
        let subtitle = "共 \(entries.count) 词 · 乱序"
        return WordSection(
            id: sectionID,
            title: "高中英语词汇3500乱序",
            subtitle: subtitle,
            words: entries,
            targetPasses: 1
        )
    }

    private static func makeEntry(from line: String) -> WordEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let bracketIndex = trimmed.firstIndex(of: "[") {
            let wordPart = String(trimmed[..<bracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wordPart.isEmpty else { return nil }
            let meaningPart = String(trimmed[bracketIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = meaningPart.isEmpty ? "-" : meaningPart
            return WordEntry(word: wordPart, meaning: meaning)
        } else {
            let components = trimmed.split(maxSplits: 1, omittingEmptySubsequences: true) { $0.isWhitespace }
            guard let first = components.first else { return nil }
            let wordPart = String(first)
            guard !wordPart.isEmpty else { return nil }
            let meaningPart = components.count > 1 ? String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let meaning = meaningPart.isEmpty ? "-" : meaningPart
            return WordEntry(word: wordPart, meaning: meaning)
        }
    }
}

private extension WordSection {
    static let sampleData: [WordSection] = [
        WordSection(
            title: "Unit 1 · Campus Life",
            subtitle: "20 词 · 高频",
            words: [
                WordEntry(word: "orientation", meaning: "n. 新生训练；方向；定位"),
                WordEntry(word: "dormitory", meaning: "n. 宿舍；学生宿舍楼"),
                WordEntry(word: "curriculum", meaning: "n. 课程；全部课程设置"),
                WordEntry(word: "faculty", meaning: "n. 全体教职员工；才能"),
                WordEntry(word: "extracurricular", meaning: "adj. 课外的；业余的"),
                WordEntry(word: "scholarship", meaning: "n. 奖学金；学识"),
                WordEntry(word: "syllabus", meaning: "n. 教学大纲；课程安排"),
                WordEntry(word: "seminar", meaning: "n. 研讨会；专题讨论课"),
                WordEntry(word: "attendance", meaning: "n. 出席；出勤率"),
                WordEntry(word: "deadline", meaning: "n. 截止日期；最后期限"),
                WordEntry(word: "assignment", meaning: "n. 任务；作业；分配"),
                WordEntry(word: "plagiarism", meaning: "n. 抄袭；剽窃行为"),
                WordEntry(word: "tuition", meaning: "n. 学费；教学"),
                WordEntry(word: "credit", meaning: "n. 学分；信用；赞扬"),
                WordEntry(word: "lecture", meaning: "n. 讲座；演讲；训诫"),
                WordEntry(word: "laboratory", meaning: "n. 实验室；实验课"),
                WordEntry(word: "internship", meaning: "n. 实习；实习期"),
                WordEntry(word: "prerequisite", meaning: "n. 先决条件；必须先具备的"),
                WordEntry(word: "mentor", meaning: "n. 导师；顾问"),
                WordEntry(word: "transcript", meaning: "n. 成绩单；抄本")
            ],
            targetPasses: 1
        ),
        WordSection(
            title: "Unit 2 · Daily Essentials",
            subtitle: "18 词 · 常用",
            words: [
                WordEntry(word: "grocery", meaning: "n. 食品杂货；食品杂货店"),
                WordEntry(word: "appliance", meaning: "n. 家用电器；器械"),
                WordEntry(word: "detergent", meaning: "n. 洗涤剂；清洁剂"),
                WordEntry(word: "utensil", meaning: "n. 器皿；用具"),
                WordEntry(word: "disposable", meaning: "adj. 一次性的；可自由支配的"),
                WordEntry(word: "refrigerate", meaning: "v. 冷藏；冷却"),
                WordEntry(word: "ingredient", meaning: "n. 成分；原料；要素"),
                WordEntry(word: "preservative", meaning: "n. 防腐剂；adj. 防腐的"),
                WordEntry(word: "sanitation", meaning: "n. 卫生；环卫设备"),
                WordEntry(word: "inventory", meaning: "n. 库存清单；存货"),
                WordEntry(word: "subscription", meaning: "n. 订阅；捐款；签署"),
                WordEntry(word: "installment", meaning: "n. 分期付款；部分"),
                WordEntry(word: "warranty", meaning: "n. 保修单；担保"),
                WordEntry(word: "invoice", meaning: "n. 发票；发货单"),
                WordEntry(word: "receipt", meaning: "n. 收据；收到"),
                WordEntry(word: "merchant", meaning: "n. 商人；批发商"),
                WordEntry(word: "checkout", meaning: "n. 结账台；检查"),
                WordEntry(word: "refund", meaning: "n./v. 退款；退还")
            ],
            targetPasses: 1
        ),
        WordSection(
            title: "IELTS 高频词",
            subtitle: "25 词 · 考试核心",
            words: [
                WordEntry(word: "accommodate", meaning: "v. 容纳；适应；向…提供住宿"),
                WordEntry(word: "accumulate", meaning: "v. 积累；堆积"),
                WordEntry(word: "advocate", meaning: "v. 提倡；拥护 n. 拥护者"),
                WordEntry(word: "allocate", meaning: "v. 分配；拨出"),
                WordEntry(word: "anticipate", meaning: "v. 预期；预料"),
                WordEntry(word: "appraise", meaning: "v. 评估；估价"),
                WordEntry(word: "articulate", meaning: "adj. 善于表达的 v. 清楚阐明"),
                WordEntry(word: "assert", meaning: "v. 声称；维护"),
                WordEntry(word: "assess", meaning: "v. 评估；估算"),
                WordEntry(word: "coincide", meaning: "v. 同时发生；一致"),
                WordEntry(word: "compensate", meaning: "v. 补偿；弥补"),
                WordEntry(word: "constrain", meaning: "v. 限制；约束"),
                WordEntry(word: "contaminate", meaning: "v. 污染；弄脏"),
                WordEntry(word: "contrast", meaning: "v. 对比；形成对比 n. 差异"),
                WordEntry(word: "contribute", meaning: "v. 贡献；促成"),
                WordEntry(word: "derive", meaning: "v. 获得；起源于"),
                WordEntry(word: "diverse", meaning: "adj. 多样的；不同的"),
                WordEntry(word: "elaborate", meaning: "adj. 精细的；详尽的 v. 详细阐述"),
                WordEntry(word: "evaluate", meaning: "v. 评估；估价"),
                WordEntry(word: "facilitate", meaning: "v. 促进；使便利"),
                WordEntry(word: "fluctuate", meaning: "v. 波动；起伏"),
                WordEntry(word: "imbue", meaning: "v. 使充满；浸染"),
                WordEntry(word: "impede", meaning: "v. 阻碍；妨碍"),
                WordEntry(word: "inevitable", meaning: "adj. 不可避免的；必然发生的"),
                WordEntry(word: "mitigate", meaning: "v. 缓和；减轻")
            ],
            targetPasses: 1
        )
    ]
}

#Preview {
    ContentView()
        .environmentObject(WordVisibilityStore())
        .environmentObject(SectionProgressStore())
}
