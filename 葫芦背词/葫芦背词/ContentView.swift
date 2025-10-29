//
//  ContentView.swift
//  葫芦背词
//
//  Created by 林凡滨 on 2025/10/14.
//

import SwiftUI
import Foundation
import UIKit

private let wordsPerPage = 10
private let appTealColor = Color(red: 0.27, green: 0.63, blue: 0.55) // 湖绿色 #45A08C

private func sanitizeUserIdentifier(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    var result = ""
    var hasAlphanumeric = false

    for scalar in value.unicodeScalars {
        if allowed.contains(scalar) {
            result.append(String(scalar))
            if CharacterSet.alphanumerics.contains(scalar) {
                hasAlphanumeric = true
            }
        } else {
            result.append("_")
        }
    }

    if hasAlphanumeric {
        return result
    }
    return "default"
}

private func namespacedKey(_ base: String, userId: String) -> String {
    "\(base).\(sanitizeUserIdentifier(userId))"
}

private enum MainTab: CaseIterable {
    case home
    case progress
    case profile

    var title: String {
        switch self {
        case .home: return "主页"
        case .progress: return "进度"
        case .profile: return "我的"
        }
    }

    var activeSymbol: String {
        switch self {
            case .home: return "house.fill"
            case .progress: return "chart.bar.fill"
            case .profile: return "person.crop.circle.fill"
        }
    }

    var inactiveSymbol: String {
        switch self {
        case .home: return "house"
        case .progress: return "chart.bar"
        case .profile: return "person.crop.circle"
        }
    }

    var order: Int {
        switch self {
        case .home: return 0
        case .progress: return 1
        case .profile: return 2
        }
    }
}

private func studiedWordCount(for section: WordSection, progressStore: SectionProgressStore) -> Int {
    let totalWords = section.words.count
    guard totalWords > 0 else { return 0 }
    let totalPages = max(1, (totalWords + wordsPerPage - 1) / wordsPerPage)
    let completedPages = max(0, min(progressStore.completedPages(for: section.id), totalPages))
    let estimatedWords = completedPages * wordsPerPage
    return min(estimatedWords, totalWords)
}

private struct BottomTabBar: View {
    @Binding var selectedTab: MainTab
    let onAddSection: () -> Void
    let showAddButton: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left side tabs
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    let isSelected = tab == selectedTab
                    Button {
                        selectedTab = tab
                        Haptic.trigger(.medium)
                    } label: {
                        let tint = labelColor(for: tab)
                        tabIcon(for: tab, isSelected: isSelected, tint: tint)
                            .frame(width: 44, height: 44)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Add button on the right
            if showAddButton {
                Button {
                    Haptic.trigger(.heavy)
                    onAddSection()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .thin))
                        .foregroundStyle(Color.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .padding(.trailing, 4)
            } else {
                Spacer()
                    .frame(width: 70)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func symbol(for tab: MainTab, isSelected: Bool) -> String {
        isSelected ? tab.activeSymbol : tab.inactiveSymbol
    }

    @ViewBuilder
    private func tabIcon(for tab: MainTab, isSelected: Bool, tint: Color) -> some View {
        switch tab {
        case .profile:
            UserIconView(color: tint, lineWidth: 1.5, isSelected: isSelected)
                .frame(width: 26, height: 26)
        case .home:
            HouseIconView(color: tint, lineWidth: 1.5, isSelected: isSelected)
                .frame(width: 26, height: 26)
        case .progress:
            BarsIconView(color: tint, lineWidth: 1.5, isSelected: isSelected)
                .frame(width: 26, height: 26)
        }
    }

    private func labelColor(for tab: MainTab) -> Color {
        tab == selectedTab ? Color(.label) : Color(.systemGray)
    }
}

private struct SectionPassesPieChart: View {
    let section: WordSection
    let progressState: SectionProgressStore.ProgressState

    private var completionRate: Double {
        guard section.targetPasses > 0 else { return 0 }
        return Double(progressState.completedPasses) / Double(section.targetPasses)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(section.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            // Pie chart
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)
                    .frame(width: 160, height: 160)

                // Progress arc
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(appTealColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: completionRate)

                // Center text
                VStack(spacing: 4) {
                    Text("\(progressState.completedPasses)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(appTealColor)
                    Text("/ \(section.targetPasses) 遍")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // Stats
            VStack(spacing: 4) {
                Text("完成度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(completionRate.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct SectionPickerView: View {
    @Binding var selectedSection: WordSection?
    let sections: [WordSection]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sections) { section in
                    Button {
                        Haptic.trigger(.light)
                        selectedSection = section
                    } label: {
                        Text(section.title)
                            .font(.system(size: 15, weight: selectedSection?.id == section.id ? .semibold : .regular))
                            .foregroundColor(selectedSection?.id == section.id ? .white : .primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedSection?.id == section.id ? appTealColor : Color(.systemGray6))
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct MonthlyProgressChart: View {
    let data: [(day: Int, words: Int)]
    let year: Int
    let month: Int
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    private let maxDataPoints = 31
    private var maxWords: Int {
        max(data.map(\.words).max() ?? 10, 10)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month selector
            HStack {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                }

                Spacer()

                Text("\(year)年\(month)月")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }

            // Chart
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    let chartHeight = geometry.size.height - 30
                    let chartWidth = geometry.size.width
                    let spacing = chartWidth / CGFloat(max(data.count, 1))

                    ZStack(alignment: .bottom) {
                        // Grid lines
                        ForEach(0..<5) { i in
                            let y = chartHeight * CGFloat(i) / 4
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: chartWidth, y: y))
                            }
                            .stroke(Color(.systemGray5), lineWidth: 1)
                        }

                        // Line chart
                        Path { path in
                            for (index, point) in data.enumerated() {
                                let x = spacing * CGFloat(index) + spacing / 2
                                let normalizedValue = CGFloat(point.words) / CGFloat(maxWords)
                                let y = chartHeight * (1 - normalizedValue)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(appTealColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        // Data points
                        ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                            let x = spacing * CGFloat(index) + spacing / 2
                            let normalizedValue = CGFloat(point.words) / CGFloat(maxWords)
                            let y = chartHeight * (1 - normalizedValue)

                            Circle()
                                .fill(point.words > 0 ? appTealColor : Color.clear)
                                .frame(width: point.words > 0 ? 6 : 0, height: point.words > 0 ? 6 : 0)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 200)

                // X-axis labels
                HStack(spacing: 0) {
                    ForEach([1, 7, 14, 21, 28], id: \.self) { day in
                        Text("\(day)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月累计")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.reduce(0) { $0 + $1.words })")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(appTealColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("日均学习")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let average = data.isEmpty ? 0 : data.reduce(0) { $0 + $1.words } / data.count
                    Text("\(average)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct ProgressOverviewView: View {
    @ObservedObject var bookStore: WordBookStore
    @ObservedObject var progressStore: SectionProgressStore
    @ObservedObject var dailyProgressStore: DailyProgressStore

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedSection: WordSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    ChartPresentationIconShape()
                        .stroke(appTealColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)

                    Text("单词进度")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 24)

                // Monthly progress chart
                MonthlyProgressChart(
                    data: dailyProgressStore.monthlyData(year: selectedYear, month: selectedMonth),
                    year: selectedYear,
                    month: selectedMonth,
                    onPreviousMonth: {
                        Haptic.trigger(.light)
                        moveToMonth(offset: -1)
                    },
                    onNextMonth: {
                        Haptic.trigger(.light)
                        moveToMonth(offset: 1)
                    }
                )
                .padding(.horizontal, 24)

                // Section selector
                if !bookStore.sections.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            CustomPieIcon()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(appTealColor)

                            Text("词书进度")
                                .font(.title2.weight(.semibold))
                        }
                        .padding(.horizontal, 24)
                        SectionPickerView(
                            selectedSection: $selectedSection,
                            sections: bookStore.sections
                        )

                        // Pie chart
                        if let section = selectedSection {
                            SectionPassesPieChart(
                                section: section,
                                progressState: progressStore.progress(for: section.id)
                            )
                            .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 140)
        }
        .background(Color(.systemGray6))
        .onAppear {
            if selectedSection == nil, let firstSection = bookStore.sections.first {
                selectedSection = firstSection
            }
        }
    }

    private func moveToMonth(offset: Int) {
        let calendar = Calendar.current
        guard let currentDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
              let newDate = calendar.date(byAdding: .month, value: offset, to: currentDate) else {
            return
        }
        selectedYear = calendar.component(.year, from: newDate)
        selectedMonth = calendar.component(.month, from: newDate)
    }

    private var totalWords: Int {
        bookStore.sections.reduce(0) { $0 + $1.words.count }
    }

    private var studiedWordsTotal: Int {
        bookStore.sections.reduce(0) { partialResult, section in
            partialResult + studiedWordCount(for: section, progressStore: progressStore)
        }
    }

    private var completedPassesTotal: Int {
        bookStore.sections.reduce(0) { partial, section in
            partial + progressStore.completedPasses(for: section.id)
        }
    }

    private var targetPassesTotal: Int {
        bookStore.sections.reduce(0) { partial, section in
            partial + max(section.targetPasses, 1)
        }
    }

    private var completionRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(studiedWordsTotal) / Double(totalWords)
    }

    private var summaryCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                VStack(alignment: .leading, spacing: 20) {
                    Text("今日学习摘要")
                        .font(.headline)

                    HStack(spacing: 16) {
                        SummaryStat(
                            title: "\(studiedWordsTotal)",
                            subtitle: "已掌握词汇"
                        )
                        SummaryStat(
                            title: "\(completedPassesTotal)/\(max(targetPassesTotal, 1))",
                            subtitle: "完成遍数"
                        )
                        SummaryStat(
                            title: "\(bookStore.sections.count)",
                            subtitle: "词书数量"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("总体完成度 \(completionRate.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: completionRate, total: 1)
                            .tint(appTealColor)
                    }
                }
                .padding(22)
            )
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }

    private var emptyPlaceholder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                    Text("暂无统计数据")
                        .font(.headline)
                    Text("在主页添加词书后即可查看复习进度。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(28)
            )
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

private struct SummaryStat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProgressSectionRow: View {
    let section: WordSection
    let studiedWords: Int
    let progressState: SectionProgressStore.ProgressState

    private var completionRatio: Double {
        guard section.words.count > 0 else { return 0 }
        return Double(studiedWords) / Double(section.words.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                Text(completionRatio.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            ProgressView(value: completionRatio, total: 1)
                .tint(Color.accentColor)

            HStack(spacing: 12) {
                Label("\(studiedWords)/\(section.words.count) 词", systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(progressState.completedPasses)/\(section.targetPasses)", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

private struct ProfileCenterView: View {
    @ObservedObject var userProfile: UserProfileStore
    @EnvironmentObject private var sessionStore: AuthSessionStore
    @EnvironmentObject private var progressStore: SectionProgressStore
    @EnvironmentObject private var dailyProgressStore: DailyProgressStore
    @EnvironmentObject private var bookStore: WordBookStore

    @State private var showingEmojiPicker = false
    @State private var showingNameEditor = false
    @State private var editingName = ""
    @State private var showingSettingsDialog = false

    private let emojiOptions = ["🎓", "📚", "✏️", "📖", "🌟", "💡", "🚀", "🎯", "🏆", "💪", "🔥", "⚡️", "🌈", "🎨", "🎭", "🎪"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerCard
                dailyStatusCard
                recentActivityCard
                learningOverviewCard

                Button {
                    Haptic.trigger(.medium)
                    sessionStore.signOut()
                } label: {
                    Text("退出登录")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                        )
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 80)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .confirmationDialog("设置", isPresented: $showingSettingsDialog, titleVisibility: .visible) {
            Button("修改昵称") {
                Haptic.trigger(.light)
                editingName = userProfile.userName
                showingNameEditor = true
            }
            Button("更换头像") {
                Haptic.trigger(.light)
                showingEmojiPicker = true
            }
            if let email = sessionStore.session?.email {
                Button("复制邮箱") {
                    UIPasteboard.general.string = email
                    Haptic.trigger(.light)
                }
            }
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(
                selectedEmoji: $userProfile.avatarEmoji,
                emojis: emojiOptions,
                isPresented: $showingEmojiPicker
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingNameEditor) {
            NameEditorView(
                name: $editingName,
                isPresented: $showingNameEditor,
                onSave: {
                    userProfile.userName = editingName
                }
            )
            .presentationDetents([.height(200)])
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Button {
                    Haptic.trigger(.light)
                    showingEmojiPicker = true
                } label: {
                    Text(userProfile.avatarEmoji)
                        .font(.system(size: 52))
                        .frame(width: 86, height: 86)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Haptic.trigger(.light)
                        editingName = userProfile.userName
                        showingNameEditor = true
                    } label: {
                        Text(userProfile.userName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let email = sessionStore.session?.email {
                        Text(email)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("未绑定邮箱")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    Text(Date(), style: .time)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                }

                Button {
                    Haptic.trigger(.light)
                    showingSettingsDialog = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(appTealColor)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(appTealColor.opacity(0.12))
                        )
                }
            }

            Divider()

            HStack(spacing: 12) {
                ProfileSummaryChip(
                    title: "词书数量",
                    value: "\(bookStore.sections.count)"
                )
                ProfileSummaryChip(
                    title: "已完成遍数",
                    value: "\(totalCompletedPasses)"
                )
                ProfileSummaryChip(
                    title: "今日单词",
                    value: "\(wordsToday)"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 12)
        )
    }

    private var dailyStatusCard: some View {
        ProfileInfoCard(
            title: "今日状态",
            subtitle: todaySubtitle,
            badge: wordsToday > 0 ? "已打卡" : "待学习",
            systemImage: wordsToday > 0 ? "checkmark.circle.fill" : "circle.dashed",
            accent: wordsToday > 0 ? Color.green : Color.orange
        )
    }

    private var recentActivityCard: some View {
        guard let recent = recentSection else {
            return ProfileInfoCard(
                title: "最近学习",
                subtitle: "还没有开始任何词书，去词书页挑选吧。",
                badge: "无记录",
                systemImage: "clock.arrow.circlepath",
                accent: Color.gray
            )
        }

        let state = progressStore.progress(for: recent.id)
        let totalPages = max(1, (recent.words.count + wordsPerPage - 1) / wordsPerPage)
        let progressText = "第 \(min(state.completedPages + 1, totalPages))/\(totalPages) 页 · 第 \(min(state.completedPasses + 1, recent.targetPasses))/\(recent.targetPasses) 遍"

        return ProfileInfoCard(
            title: "最近学习",
            subtitle: "\(recent.title)\n\(progressText)",
            badge: "继续学习",
            systemImage: "book.circle",
            accent: appTealColor
        )
    }

    private var learningOverviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("学习纵览")
                .font(.system(size: 20, weight: .semibold))

            VStack(spacing: 14) {
                overviewRow(title: "累计词书", value: "\(bookStore.sections.count) 本", icon: "books.vertical")
                overviewRow(title: "累计遍数", value: "\(totalCompletedPasses) 遍", icon: "repeat.circle")
                overviewRow(title: "今日单词", value: "\(wordsToday) 个", icon: "sun.max")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 10)
        )
    }

    private func overviewRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(appTealColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(appTealColor.opacity(0.12))
                )

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    private var wordsToday: Int {
        dailyProgressStore.wordsLearned(on: Date())
    }

    private var todaySubtitle: String {
        if wordsToday == 0 {
            return "今天还没有学习，完成一页词书即可点亮进度。"
        }
        if wordsToday < wordsPerPage {
            return "刚刚起步，继续努力完成下一页吧。"
        }
        return "已学习 \(wordsToday) 个单词，保持势头！"
    }

    private var totalCompletedPasses: Int {
        bookStore.sections.reduce(0) { result, section in
            result + progressStore.completedPasses(for: section.id)
        }
    }

    private var recentSection: WordSection? {
        bookStore.sections.max { lhs, rhs in
            progressScore(for: lhs) < progressScore(for: rhs)
        }
    }

    private func progressScore(for section: WordSection) -> Int {
        let state = progressStore.progress(for: section.id)
        return state.completedPasses * 10_000 + state.completedPages
    }
}

private struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("选择头像")
                .font(.headline)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        Haptic.trigger(.medium)
                        selectedEmoji = emoji
                        isPresented = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 50))
                            .frame(width: 70, height: 70)
                            .background(
                                Circle()
                                    .fill(emoji == selectedEmoji ? appTealColor.opacity(0.2) : Color(.systemGray6))
                            )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

private struct NameEditorView: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("编辑名字")
                .font(.headline)
                .padding(.top, 20)

            TextField("输入名字", text: $name)
                .font(.system(size: 18))
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 24)

            Button {
                Haptic.trigger(.medium)
                onSave()
                isPresented = false
            } label: {
                Text("保存")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(appTealColor)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

private struct ProfileActionButton: View {
    enum Style {
        case accent
        case plain
        case destructive

        var background: Color {
            switch self {
            case .accent: return Color.accentColor.opacity(0.12)
            case .plain: return Color(.systemGray6)
            case .destructive: return Color.red.opacity(0.12)
            }
        }

        var foreground: Color {
            switch self {
            case .accent: return Color.accentColor
            case .plain: return Color.primary
            case .destructive: return Color.red
            }
        }
    }

    let title: String
    let subtitle: String
    let systemImage: String?
    let style: Style
    let customIcon: AnyView?
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        systemImage: String? = nil,
        style: Style,
        customIcon: AnyView? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.style = style
        self.customIcon = customIcon
        self.action = action
    }

    var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            HStack(spacing: 16) {
                iconView
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(style.background))
                    .foregroundStyle(style.foreground)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func triggerHaptic() {
        switch style {
        case .accent:
            Haptic.trigger(.medium)
        case .plain:
            Haptic.trigger(.light)
        case .destructive:
            Haptic.trigger(.heavy)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let customIcon {
            customIcon
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
        } else {
            EmptyView()
        }
    }
}

private struct ProfileSummaryChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(appTealColor)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

private struct ProfileInfoCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text(badge)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                    )
            }

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(0.12))
                    )

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 10)
        )
    }
}

private struct AddWordBookIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(appTealColor)

            Image(systemName: "plus")
                .font(.system(size: 12, weight: .thin))
                .foregroundColor(.white)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ImportWordsIcon: View {
    var body: some View {
        ImportWordsShape()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct ImportWordsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()
        path.move(to: point(3.75, 13.5))
        path.addLine(to: point(14.25, 2.25))
        path.addLine(to: point(12.0, 10.5))
        path.addLine(to: point(20.25, 10.5))
        path.addLine(to: point(9.75, 21.75))
        path.addLine(to: point(12.0, 13.5))
        path.addLine(to: point(3.75, 13.5))
        path.closeSubpath()
        return path
    }
}

private struct CustomBookIcon: View {
    var body: some View {
        CustomBookIconShape()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct CustomBookIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // Left page: M12 6.042 -> curve to 6,3.75 -> curve to 3,4.262 -> line to 3,18.512 -> curve to 6,18 -> curve to 12,20.292
        path.move(to: point(12, 6.042))

        // Curve from center top to left top
        path.addQuadCurve(to: point(6, 3.75), control: point(9, 4.5))

        // Curve to left edge
        path.addQuadCurve(to: point(3, 4.262), control: point(4, 3.8))

        // Vertical line down
        path.addLine(to: point(3, 18.512))

        // Curve to left bottom
        path.addQuadCurve(to: point(6, 18), control: point(4, 18.3))

        // Curve back to center bottom
        path.addQuadCurve(to: point(12, 20.292), control: point(9, 19.5))

        // Right page: M12 6.042 -> curve to 18,3.75 -> curve to 21,4.262 -> line to 21,18.512 -> curve to 18,18 -> curve to 12,20.292
        path.move(to: point(12, 6.042))

        // Curve from center top to right top
        path.addQuadCurve(to: point(18, 3.75), control: point(15, 4.5))

        // Curve to right edge
        path.addQuadCurve(to: point(21, 4.262), control: point(20, 3.8))

        // Vertical line down
        path.addLine(to: point(21, 18.512))

        // Curve to right bottom
        path.addQuadCurve(to: point(18, 18), control: point(20, 18.3))

        // Curve back to center bottom
        path.addQuadCurve(to: point(12, 20.292), control: point(15, 19.5))

        // Center vertical line
        path.move(to: point(12, 6.042))
        path.addLine(to: point(12, 20.292))

        return path
    }
}

private struct CustomRepeatIcon: View {
    var body: some View {
        CustomRepeatIconShape()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct CustomRepeatIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // Top right arrow: M16.023 9.348 h4.992 v-.001
        path.move(to: point(16.023, 9.348))
        path.addLine(to: point(21.015, 9.348))
        path.addLine(to: point(21.015, 9.347))

        // Bottom left arrow: M2.985 19.644 v-4.992 m0 0 h4.992 m-4.993 0 l3.181 3.183
        path.move(to: point(2.985, 19.644))
        path.addLine(to: point(2.985, 14.652))

        path.move(to: point(2.985, 14.652))
        path.addLine(to: point(7.977, 14.652))

        path.move(to: point(2.985, 14.652))
        path.addLine(to: point(6.166, 17.835))

        // Top curve: a8.25 8.25 0 0 0 13.803-3.7
        // Starting from (6.166, 17.835), curve through arc
        path.addArc(
            center: point(12, 12),
            radius: 8.25 * scale,
            startAngle: .degrees(125),
            endAngle: .degrees(30),
            clockwise: true
        )

        // Bottom curve: M4.031 9.865 a8.25 8.25 0 0 1 13.803-3.7 l3.181 3.182
        path.move(to: point(4.031, 9.865))
        path.addArc(
            center: point(12, 12),
            radius: 8.25 * scale,
            startAngle: .degrees(210),
            endAngle: .degrees(315),
            clockwise: false
        )
        path.addLine(to: point(21.015, 9.347))

        // Arrow at top right: m0-4.991 v4.99
        path.move(to: point(21.015, 4.356))
        path.addLine(to: point(21.015, 9.346))

        return path
    }
}

private struct TrashIcon: View {
    var body: some View {
        TrashShape()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct TrashShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // Inner can lines
        path.move(to: point(14.74, 9.0))
        path.addLine(to: point(14.394, 18.0))
        path.move(to: point(9.606, 18.0))
        path.addLine(to: point(9.26, 9.0))

        // Outer body
        path.move(to: point(19.228, 5.79))
        path.addLine(to: point(18.16, 19.673))
        path.addQuadCurve(to: point(15.916, 21.75), control: point(18.0, 21.6))
        path.addLine(to: point(8.084, 21.75))
        path.addQuadCurve(to: point(5.84, 19.673), control: point(6.0, 21.6))
        path.addLine(to: point(4.772, 5.79))
        path.addQuadCurve(to: point(8.25, 5.393), control: point(6.4, 5.5))
        path.addLine(to: point(8.25, 4.477))
        path.addQuadCurve(to: point(10.34, 2.276), control: point(8.3, 3.2))
        path.addLine(to: point(13.66, 2.276))
        path.addQuadCurve(to: point(15.75, 4.477), control: point(15.7, 3.2))
        path.addLine(to: point(15.75, 5.393))
        path.addQuadCurve(to: point(19.228, 5.79), control: point(17.6, 5.5))
        path.closeSubpath()

        return path
    }
}

private struct EditIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // Pencil stroke
        path.move(to: point(16.862, 4.487))
        path.addLine(to: point(18.549, 2.799))
        path.addArc(center: point(19.875, 4.125), radius: 1.875 * scale, startAngle: .degrees(225), endAngle: .degrees(45), clockwise: false)
        path.addLine(to: point(10.582, 16.07))
        path.addLine(to: point(8.685, 17.2))
        path.addLine(to: point(6, 18))
        path.addLine(to: point(6.8, 15.315))
        path.addLine(to: point(7.93, 13.418))
        path.addLine(to: point(16.862, 4.487))

        // Pencil to square connector
        path.move(to: point(16.862, 4.487))
        path.addLine(to: point(19.5, 7.125))

        // Document outline
        path.move(to: point(18, 14))
        path.addLine(to: point(18, 18.75))
        path.addArc(center: point(15.75, 18.75), radius: 2.25 * scale, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: point(5.25, 21))
        path.addArc(center: point(5.25, 18.75), radius: 2.25 * scale, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: point(3, 8.25))
        path.addArc(center: point(5.25, 8.25), radius: 2.25 * scale, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: point(10, 6))

        return path
    }
}

private struct ChartPresentationIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // Top monitor frame
        path.move(to: point(3.75, 3))
        path.addLine(to: point(3.75, 14.25))
        path.addArc(center: point(6, 14.25), radius: 2.25 * scale, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: point(8.25, 16.5))

        path.move(to: point(3.75, 3))
        path.addLine(to: point(2.25, 3))

        path.move(to: point(3.75, 3))
        path.addLine(to: point(20.25, 3))

        path.move(to: point(20.25, 3))
        path.addLine(to: point(21.75, 3))

        path.move(to: point(20.25, 3))
        path.addLine(to: point(20.25, 14.25))
        path.addArc(center: point(18, 14.25), radius: 2.25 * scale, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: point(15.75, 16.5))

        // Bottom stand
        path.move(to: point(8.25, 16.5))
        path.addLine(to: point(15.75, 16.5))

        path.move(to: point(8.25, 16.5))
        path.addLine(to: point(7.25, 19.5))

        path.move(to: point(15.75, 16.5))
        path.addLine(to: point(16.75, 19.5))

        path.move(to: point(16.75, 19.5))
        path.addLine(to: point(17.25, 21))

        path.move(to: point(16.75, 19.5))
        path.addLine(to: point(7.25, 19.5))

        path.move(to: point(7.25, 19.5))
        path.addLine(to: point(6.75, 21))

        // Chart line inside
        path.move(to: point(9.75, 12))
        path.addLine(to: point(12.75, 9))
        path.addLine(to: point(14.898, 11.148))
        // Curve approximation
        let control1 = point(15.3, 10.5)
        let control2 = point(15.8, 10.0)
        path.addCurve(to: point(16.5, 7.605), control1: control1, control2: control2)

        return path
    }
}

private struct CustomPieIcon: View {
    var lineWidth: CGFloat = 1.5

    var body: some View {
        ZStack {
            CustomPieLargeSlice()
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            CustomPieSmallSlice()
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CustomPieLargeSlice: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // M2.25 13.5
        path.move(to: point(2.25, 13.5))

        // a8.25 8.25 0 0 1 8.25-8.25
        path.addArc(
            center: point(10.5, 13.5),
            radius: 8.25 * scale,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // .75.75 0 0 1 .75.75
        path.addArc(
            center: point(10.5, 6),
            radius: 0.75 * scale,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: false
        )

        // v6.75
        path.addLine(to: point(11.25, 12.75))

        // H18
        path.addLine(to: point(18, 12.75))

        // a.75.75 0 0 1 .75.75
        path.addArc(
            center: point(18, 13.5),
            radius: 0.75 * scale,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        // a8.25 8.25 0 0 1-16.5 0
        path.addArc(
            center: point(10.5, 13.5),
            radius: 8.25 * scale,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

private struct CustomPieSmallSlice: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        // M12.75 3
        path.move(to: point(12.75, 3))

        // a.75.75 0 0 1 .75-.75
        path.addArc(
            center: point(13.5, 3),
            radius: 0.75 * scale,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // a8.25 8.25 0 0 1 8.25 8.25
        path.addArc(
            center: point(13.5, 10.5),
            radius: 8.25 * scale,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        // a.75.75 0 0 1-.75.75
        path.addArc(
            center: point(21, 10.5),
            radius: 0.75 * scale,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // h-7.5
        path.addLine(to: point(13.5, 11.25))

        // a.75.75 0 0 1-.75-.75
        path.addArc(
            center: point(12.75, 10.5),
            radius: 0.75 * scale,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )

        // V3
        path.addLine(to: point(12.75, 3))

        path.closeSubpath()
        return path
    }
}

final class WordBookStore: ObservableObject {
    @Published private(set) var sections: [WordSection] = []

    private let storageURL: URL

    init(userId: String, fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sanitizedUserId = sanitizeUserIdentifier(userId)
        storageURL = directory.appendingPathComponent("wordbook-\(sanitizedUserId).json")

        let legacyURL = directory.appendingPathComponent("wordbook.json")
        if fileManager.fileExists(atPath: legacyURL.path),
           !fileManager.fileExists(atPath: storageURL.path) {
            try? fileManager.copyItem(at: legacyURL, to: storageURL)
        }

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
        let bundledSections = BundledWordBookLoader.loadAll()
        for bundledSection in bundledSections {
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
    @EnvironmentObject private var sessionStore: AuthSessionStore
    @StateObject private var bookStore: WordBookStore
    @State private var showingAddSection = false
    @State private var sectionToDelete: WordSection?
    @State private var editingSection: WordSection?
    @StateObject private var hideState: WordVisibilityStore
    @StateObject private var progressStore: SectionProgressStore
    @StateObject private var dailyProgressStore: DailyProgressStore
    @StateObject private var userProfile: UserProfileStore
    @State private var showingAutomationAgent = false
    @State private var importingSection: WordSection?
    @State private var selectedTab: MainTab = .home
    @State private var isRootView: Bool = true
    @State private var previousTab: MainTab = .home

    init(session: AuthSession) {
        let userId = session.userId
        _bookStore = StateObject(wrappedValue: WordBookStore(userId: userId))
        _hideState = StateObject(wrappedValue: WordVisibilityStore(userId: userId))
        _progressStore = StateObject(wrappedValue: SectionProgressStore(userId: userId))
        _dailyProgressStore = StateObject(wrappedValue: DailyProgressStore(userId: userId))
        _userProfile = StateObject(wrappedValue: UserProfileStore(userId: userId))
    }

    var body: some View {
        NavigationStack {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGray6).ignoresSafeArea())
                .onChange(of: selectedTab) { oldValue, _ in
                    previousTab = oldValue
                    isRootView = true
                }
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
                    .environmentObject(dailyProgressStore)
                    .onAppear {
                        isRootView = false
                    }
                    .onDisappear {
                        isRootView = true
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(appTealColor)
        .safeAreaInset(edge: .bottom) {
            if isRootView {
                BottomTabBar(
                    selectedTab: $selectedTab,
                    onAddSection: { showingAddSection = true },
                    showAddButton: true
                )
            } else {
                EmptyView()
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
        .sheet(item: $importingSection, content: { section in
            QuickImportSheet(section: section) { entries in
                let result = importWords(entries, intoSectionID: section.id)
                if let refreshed = bookStore.sections.first(where: { $0.id == section.id }) {
                    importingSection = refreshed
                }
                return result
            }
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
                Haptic.trigger(.light)
                sectionToDelete = nil
            }
            Button("删除", role: .destructive) {
                Haptic.trigger(.heavy)
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

    private var tabContent: some View {
        ZStack {
            if selectedTab == .home {
                homeView
                    .transition(transition(for: .home))
            }
            if selectedTab == .progress {
                ProgressOverviewView(bookStore: bookStore, progressStore: progressStore, dailyProgressStore: dailyProgressStore)
                    .transition(transition(for: .progress))
            }
            if selectedTab == .profile {
                ProfileCenterView(userProfile: userProfile)
                    .transition(transition(for: .profile))
                    .environmentObject(bookStore)
                    .environmentObject(progressStore)
                    .environmentObject(dailyProgressStore)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: selectedTab)
    }

    private func transition(for tab: MainTab) -> AnyTransition {
        let newIndex = tab.order
        let oldIndex = previousTab.order

        guard newIndex != oldIndex else {
            return .identity
        }

        let insertionEdge: Edge = newIndex > oldIndex ? .trailing : .leading
        let removalEdge: Edge = newIndex > oldIndex ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView

                LazyVStack(spacing: 24) {
                    ForEach(bookStore.sections) { section in
                        let studied = studiedWordCount(for: section, progressStore: progressStore)
                        let progressState = progressStore.progress(for: section.id)
                        NavigationLink(value: section.id) {
                            SectionCardView(
                                section: section,
                                studiedWords: studied,
                                completedPasses: progressState.completedPasses,
                                onDelete: {
                                    sectionToDelete = section
                                },
                                onImport: {
                                    importingSection = section
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 220)
        }
    }

    private var headerView: some View {
        HStack(spacing: 14) {
            AppIconBadge()

            Text("葫芦背词")
                .font(.title2.weight(.semibold))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func importWords(_ entries: [WordEntry], intoSectionID id: UUID) -> QuickImportResult {
        guard let existing = bookStore.sections.first(where: { $0.id == id }) else {
            return QuickImportResult(addedCount: 0, duplicateWords: [])
        }

        var existingWords = Set(existing.words.map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var additions: [WordEntry] = []
        var duplicates: [String] = []

        for entry in entries {
            let trimmedWord = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedMeaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedWord.isEmpty else { continue }

            let lower = trimmedWord.lowercased()
            if existingWords.contains(lower) {
                duplicates.append(trimmedWord)
                continue
            }

            additions.append(WordEntry(word: trimmedWord, meaning: trimmedMeaning.isEmpty ? "-" : trimmedMeaning))
            existingWords.insert(lower)
        }

        guard !additions.isEmpty else {
            return QuickImportResult(addedCount: 0, duplicateWords: duplicates)
        }

        var mergedWords = existing.words
        mergedWords.append(contentsOf: additions)

        let updatedSection = WordSection(
            id: existing.id,
            title: existing.title,
            subtitle: existing.subtitle,
            words: mergedWords,
            targetPasses: existing.targetPasses
        )

        bookStore.updateSection(updatedSection)
        let totalPages = max(updatedSection.words.chunked(into: wordsPerPage).count, 1)
        progressStore.clampProgress(for: updatedSection.id, totalPages: totalPages, targetPasses: updatedSection.targetPasses)

        return QuickImportResult(addedCount: additions.count, duplicateWords: duplicates)
    }

}

private struct UserIconView: View {
    var color: Color
    var lineWidth: CGFloat
    var isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                UserIconShape()
                    .fill(color)
            }
            UserIconShape()
                .stroke(color, lineWidth: lineWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(nil, value: isSelected)
    }
}

private struct HouseIconView: View {
    var color: Color
    var lineWidth: CGFloat
    var isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                HouseFillShape()
                    .fill(color)
                HouseDoorShape()
                    .fill(Color(.systemBackground))
            }
            HouseStrokeShape()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(nil, value: isSelected)
    }
}

private struct BarsIconView: View {
    var color: Color
    var lineWidth: CGFloat
    var isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                BarsIconShape(lineWidth: lineWidth)
                    .fill(color)
            }
            BarsIconShape(lineWidth: lineWidth)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(nil, value: isSelected)
    }
}

private struct UserIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let scale = minSide / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        let headCenter = CGPoint(x: offsetX + 12 * scale, y: offsetY + 6 * scale)
        let headRadius = 3.75 * scale

        let bodyStart = CGPoint(x: offsetX + 4.501 * scale, y: offsetY + 20.118 * scale)
        let bodyCenter = CGPoint(x: offsetX + 12 * scale, y: offsetY + 20.118 * scale)
        let bodyRadius = 7.5 * scale
        let bottomControl = CGPoint(x: offsetX + 12 * scale, y: offsetY + 21.75 * scale)

        var path = Path()
        let headRect = CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius, width: headRadius * 2, height: headRadius * 2)
        path.addEllipse(in: headRect)

        var torso = Path()
        torso.move(to: bodyStart)
        torso.addArc(center: bodyCenter, radius: bodyRadius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        torso.addQuadCurve(to: bodyStart, control: bottomControl)
        torso.closeSubpath()
        path.addPath(torso)

        return path
    }
}

private struct HouseStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let scale = minSide / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()
        path.move(to: point(2.25, 12))
        path.addLine(to: point(12, 3))
        path.addLine(to: point(21.75, 12))

        path.move(to: point(4.5, 11))
        path.addLine(to: point(4.5, 20))
        path.addCurve(to: point(5.625, 21.125), control1: point(4.5, 20.621), control2: point(5.004, 21.125))
        path.addLine(to: point(9.75, 21.125))
        path.addLine(to: point(9.75, 16.25))
        path.addCurve(to: point(10.875, 15.125), control1: point(9.75, 15.629), control2: point(10.254, 15.125))
        path.addLine(to: point(13.125, 15.125))
        path.addCurve(to: point(14.25, 16.25), control1: point(13.746, 15.125), control2: point(14.25, 15.629))
        path.addLine(to: point(14.25, 21.125))
        path.addLine(to: point(18.375, 21.125))
        path.addCurve(to: point(19.5, 20), control1: point(18.996, 21.125), control2: point(19.5, 20.621))
        path.addLine(to: point(19.5, 11))

        path.move(to: point(8.25, 21))
        path.addLine(to: point(16.5, 21))

        return path
    }
}

private struct HouseFillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let scale = minSide / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()
        path.move(to: point(2.25, 12))
        path.addLine(to: point(12, 3))
        path.addLine(to: point(21.75, 12))
        path.closeSubpath()

        let bodyRect = CGRect(
            x: offsetX + 4.5 * scale,
            y: offsetY + 11 * scale,
            width: 15 * scale,
            height: 10.75 * scale
        )
        path.addRect(bodyRect)

        return path
    }
}

private struct HouseDoorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let scale = minSide / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        let doorRect = CGRect(
            x: offsetX + 9.75 * scale,
            y: offsetY + 15.125 * scale,
            width: 4.5 * scale,
            height: 5.875 * scale
        )
        return Path(roundedRect: doorRect, cornerRadius: 1.2 * scale)
    }
}

private struct BarsIconShape: Shape {
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let minSide = min(rect.width, rect.height)
        let scale = minSide / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func scaledRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: offsetX + x * scale,
                   y: offsetY + y * scale,
                   width: width * scale,
                   height: height * scale)
        }

        let corner = max(lineWidth * 1.2, 1.5 * scale)

        var path = Path()
        path.addPath(Path(roundedRect: scaledRect(3.0, 12.0, 3.0, 9.0), cornerRadius: corner))
        path.addPath(Path(roundedRect: scaledRect(9.75, 7.5, 3.0, 13.5), cornerRadius: corner))
        path.addPath(Path(roundedRect: scaledRect(16.5, 3.0, 3.0, 18.0), cornerRadius: corner))

        return path
    }
}

private struct AppIconBadge: View {
    private let size: CGFloat = 48

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Group {
            if let icon = UIImage.appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "character.book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .background(shape.fill(Color(.systemBackground)))
        .clipShape(shape)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

private extension UIImage {
    static var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primary["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last,
            let icon = UIImage(named: iconName)
        else {
            return nil
        }
        return icon
    }
}

private struct SectionCardView: View {
    let section: WordSection
    let studiedWords: Int
    let completedPasses: Int
    let onDelete: () -> Void
    let onImport: () -> Void

    private var normalizedPassCount: Int {
        let target = max(section.targetPasses, 1)
        return min(max(completedPasses, 0), target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    if let subtitle = section.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    CustomBookIcon()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                    Text("\(section.words.count)/\(studiedWords)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    CustomRepeatIcon()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                    Text("\(section.targetPasses)/\(normalizedPassCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Button {
                    Haptic.trigger(.light)
                    onImport()
                } label: {
                    ImportWordsIcon()
                        .frame(width: 16, height: 16)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )
                .accessibilityLabel("导入单词")

                Button {
                    Haptic.trigger(.heavy)
                    onDelete()
                } label: {
                    TrashIcon()
                        .frame(width: 16, height: 16)
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
                            Haptic.trigger(.light)
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
                            Haptic.trigger(.light)
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
    @EnvironmentObject private var dailyProgressStore: DailyProgressStore

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
                        Haptic.trigger(.light)
                        onEdit(section)
                    } label: {
                        EditIconShape()
                            .stroke(appTealColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: 26, height: 26)
                            .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }
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
        let wordsOnPage = pageEntries[currentPage].count

        let state = progressStore.markPageCompleted(sectionID: section.id, totalPages: total, pageIndex: currentPage, targetPasses: section.targetPasses)

        // Record daily progress
        dailyProgressStore.recordWordsLearned(count: wordsOnPage)

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
                            Haptic.trigger(.light)
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
                    Haptic.trigger(.light)
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
    @State private var targetPassesText: String
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
            let passes = max(section.targetPasses, 1)
            _targetPasses = State(initialValue: passes)
            _targetPassesText = State(initialValue: "\(passes)")
            _searchText = State(initialValue: "")
        } else {
            _title = State(initialValue: "")
            _subtitle = State(initialValue: "")
            _entries = State(initialValue: [AddEntry()])
            _targetPasses = State(initialValue: 1)
            _targetPassesText = State(initialValue: "1")
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
                        HStack {
                            Text("目标遍数")
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    Haptic.trigger(.light)
                                    if targetPasses > 1 {
                                        targetPasses -= 1
                                        targetPassesText = "\(targetPasses)"
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(targetPasses > 1 ? appTealColor : Color.gray.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .disabled(targetPasses <= 1)

                                TextField("", text: $targetPassesText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                                    .onChange(of: targetPassesText) { _, newValue in
                                        if let number = Int(newValue), number > 0 {
                                            targetPasses = number
                                        } else if newValue.isEmpty {
                                            targetPasses = 1
                                        } else {
                                            // 如果输入无效，恢复到上一个有效值
                                            targetPassesText = "\(targetPasses)"
                                        }
                                    }

                                Button {
                                    Haptic.trigger(.light)
                                    targetPasses += 1
                                    targetPassesText = "\(targetPasses)"
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(appTealColor)
                                }
                                .buttonStyle(.plain)
                            }
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
                                    Haptic.trigger(.heavy)
                                    removeEntry(withID: entry.id)
                                } label: {
                                    Label {
                                        Text("删除")
                                    } icon: {
                                        TrashIcon()
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }
                        }

                        Button {
                            Haptic.trigger(.light)
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
                        Button("取消") {
                            Haptic.trigger(.light)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Haptic.trigger(.medium)
                            saveSection()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .alert(errorMessage ?? "", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { _ in errorMessage = nil }
                )) {
                    Button("好的", role: .cancel) {
                        Haptic.trigger(.light)
                    }
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

private struct QuickImportResult {
    let addedCount: Int
    let duplicateWords: [String]
}

private struct QuickImportSheet: View {
    let section: WordSection
    let onImport: ([WordEntry]) -> QuickImportResult

    @Environment(\.dismiss) private var dismiss

    @State private var rawInput: String = ""
    @State private var resultMessage: String?
    @State private var warningMessage: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("将单词追加到“\(section.title)” 中。每一行使用 “单词|释义” 的格式，例如：\nabandon|v. 放弃")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if rawInput.isEmpty {
                        Text("单词|释义")
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.horizontal, 6)
                    }
                    TextEditor(text: $rawInput)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
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

                if let warningMessage {
                    Label(warningMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.orange)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("导入单词")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        Haptic.trigger(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        processInput()
                    } label: {
                        Text(isProcessing ? "处理中…" : "导入")
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    private func processInput() {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Haptic.trigger(.light)
            resultMessage = nil
            warningMessage = "请输入需要导入的单词。"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let lines = trimmed.components(separatedBy: .newlines)
        var parsedEntries: [WordEntry] = []
        var invalidLines: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let components = line.components(separatedBy: "|")
            guard components.count >= 2 else {
                invalidLines.append(rawLine)
                continue
            }

            let word = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = components.dropFirst().joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)

            guard !word.isEmpty else {
                invalidLines.append(rawLine)
                continue
            }

            parsedEntries.append(WordEntry(word: word, meaning: meaning.isEmpty ? "-" : meaning))
        }

        guard !parsedEntries.isEmpty else {
            Haptic.trigger(.light)
            resultMessage = nil
            warningMessage = invalidLines.isEmpty
                ? "没有识别到有效的单词，请按照 “单词|释义” 的格式输入。"
                : "以下行格式不正确：\(summarizedList(invalidLines))"
            return
        }

        let result = onImport(parsedEntries)

        var warnings: [String] = []
        if !invalidLines.isEmpty {
            warnings.append("已跳过无法识别的行：\(summarizedList(invalidLines))")
        }
        if !result.duplicateWords.isEmpty {
            warnings.append("已跳过重复单词：\(summarizedList(result.duplicateWords))")
        }

        if result.addedCount > 0 {
            Haptic.trigger(.medium)
            resultMessage = "成功导入 \(result.addedCount) 个单词至“\(section.title)”"
            warningMessage = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
            rawInput = ""
        } else {
            Haptic.trigger(.light)
            resultMessage = nil
            warnings.append("没有导入新的单词。")
            warningMessage = warnings.joined(separator: "\n")
        }
    }

    private func summarizedList(_ items: [String], limit: Int = 5) -> String {
        guard !items.isEmpty else { return "" }
        if items.count <= limit {
            return items.joined(separator: "、")
        } else {
            let prefixItems = items.prefix(limit).joined(separator: "、")
            return "\(prefixItems) 等共 \(items.count) 项"
        }
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
                        Haptic.trigger(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Haptic.trigger(.medium)
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
    private let defaultsKey: String
    private static let legacyDefaultsKey = "SectionProgressStore.v1"
    private var isRestoring = false

    init(userId: String, userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.defaultsKey = namespacedKey(Self.legacyDefaultsKey, userId: userId)
        loadInitialState()
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

    func resetAllProgress() {
        if !progressStates.isEmpty {
            progressStates.removeAll()
        }
    }

    private func persist() {
        guard !isRestoring,
              let data = try? JSONEncoder().encode(progressStates) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private func loadInitialState() {
        var migratedFromLegacy = false

        if let data = defaults.data(forKey: defaultsKey) {
            _ = decodeProgress(from: data)
        } else if let legacyData = defaults.data(forKey: Self.legacyDefaultsKey),
                  decodeProgress(from: legacyData) {
            migratedFromLegacy = true
        }

        if migratedFromLegacy {
            persist()
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        }
    }

    @discardableResult
    private func decodeProgress(from data: Data) -> Bool {
        let decoder = JSONDecoder()

        if let decoded = try? decoder.decode([UUID: ProgressState].self, from: data) {
            isRestoring = true
            progressStates = decoded
            isRestoring = false
            return true
        }

        if let legacy = try? decoder.decode([UUID: Int].self, from: data) {
            isRestoring = true
            progressStates = legacy.reduce(into: [:]) { result, element in
                result[element.key] = ProgressState(completedPages: element.value, completedPasses: 0)
            }
            isRestoring = false
            return true
        }

        return false
    }
}

final class DailyProgressStore: ObservableObject {
    struct DailyRecord: Codable {
        let date: String  // Format: "yyyy-MM-dd"
        var wordsLearned: Int
    }

    @Published private var records: [String: Int] = [:] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let defaultsKey: String
    private static let legacyDefaultsKey = "DailyProgressStore.v1"
    private var isRestoring = false

    init(userId: String, userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.defaultsKey = namespacedKey(Self.legacyDefaultsKey, userId: userId)
        loadInitialState()
    }

    func recordWordsLearned(count: Int, date: Date = Date()) {
        let dateString = dateFormatter.string(from: date)
        records[dateString, default: 0] += count
    }

    func wordsLearned(on date: Date) -> Int {
        let dateString = dateFormatter.string(from: date)
        return records[dateString] ?? 0
    }

    func monthlyData(year: Int, month: Int) -> [(day: Int, words: Int)] {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }

        return range.map { day in
            let dateComponents = DateComponents(year: year, month: month, day: day)
            guard let dayDate = calendar.date(from: dateComponents) else {
                return (day, 0)
            }
            return (day, wordsLearned(on: dayDate))
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func persist() {
        guard !isRestoring,
              let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private func loadInitialState() {
        var migratedFromLegacy = false

        if let data = defaults.data(forKey: defaultsKey) {
            _ = decodeRecords(from: data)
        } else if let legacyData = defaults.data(forKey: Self.legacyDefaultsKey),
                  decodeRecords(from: legacyData) {
            migratedFromLegacy = true
        }

        if migratedFromLegacy {
            persist()
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        }
    }

    @discardableResult
    private func decodeRecords(from data: Data) -> Bool {
        let decoder = JSONDecoder()

        if let decoded = try? decoder.decode([String: Int].self, from: data) {
            isRestoring = true
            records = decoded
            isRestoring = false
            return true
        }

        return false
    }
}

final class UserProfileStore: ObservableObject {
    @Published var userName: String {
        didSet { persist() }
    }

    @Published var avatarEmoji: String {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let nameKey: String
    private let emojiKey: String
    private static let legacyNameKey = "UserProfileStore.name"
    private static let legacyEmojiKey = "UserProfileStore.emoji"

    init(userId: String, userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.nameKey = namespacedKey(Self.legacyNameKey, userId: userId)
        self.emojiKey = namespacedKey(Self.legacyEmojiKey, userId: userId)

        var migrated = false

        if let storedName = userDefaults.string(forKey: nameKey) {
            self.userName = storedName
        } else if let legacyName = userDefaults.string(forKey: Self.legacyNameKey) {
            self.userName = legacyName
            migrated = true
            defaults.removeObject(forKey: Self.legacyNameKey)
        } else {
            self.userName = "学习者"
        }

        if let storedEmoji = userDefaults.string(forKey: emojiKey) {
            self.avatarEmoji = storedEmoji
        } else if let legacyEmoji = userDefaults.string(forKey: Self.legacyEmojiKey) {
            self.avatarEmoji = legacyEmoji
            migrated = true
            defaults.removeObject(forKey: Self.legacyEmojiKey)
        } else {
            self.avatarEmoji = "🎓"
        }

        if migrated {
            persist()
        }
    }

    private func persist() {
        defaults.set(userName, forKey: nameKey)
        defaults.set(avatarEmoji, forKey: emojiKey)
    }
}

final class WordVisibilityStore: ObservableObject {
    @Published private var visibility: [UUID: EntryVisibility] = [:] {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let defaultsKey: String
    private static let legacyDefaultsKey = "WordVisibilityStore.v1"
    private var isRestoring = false

    init(userId: String, userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.defaultsKey = namespacedKey(Self.legacyDefaultsKey, userId: userId)
        loadInitialState()
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

    func resetAll() {
        if !visibility.isEmpty {
            visibility.removeAll()
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

    private func loadInitialState() {
        var migratedFromLegacy = false

        if let data = defaults.data(forKey: defaultsKey),
           decodeVisibility(from: data) {
            return
        } else if let legacyData = defaults.data(forKey: Self.legacyDefaultsKey),
                  decodeVisibility(from: legacyData) {
            migratedFromLegacy = true
        }

        if migratedFromLegacy {
            persist()
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        }
    }

    @discardableResult
    private func decodeVisibility(from data: Data) -> Bool {
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([UUID: EntryVisibility].self, from: data) {
            isRestoring = true
            visibility = decoded
            isRestoring = false
            return true
        }
        return false
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

    private struct ResourceDescriptor {
        let fileName: String
        let title: String
        let sectionID: UUID
    }

    private static let resourceExtension = "txt"
    private static let descriptors: [ResourceDescriptor] = [
        .init(
            fileName: "highschool3500_shuffled",
            title: "高中英语词汇3500乱序",
            sectionID: UUID(uuidString: "095D66A2-6E17-42A3-B0FA-9022D3AD4398")!
        ),
        .init(
            fileName: "4 六级-乱序",
            title: "六级词汇乱序",
            sectionID: UUID(uuidString: "5E6E7A45-D6A8-4A18-97F4-9FA9E773D6A2")!
        ),
        .init(
            fileName: "5 考研-乱序",
            title: "考研词汇乱序",
            sectionID: UUID(uuidString: "12F6BBD0-8CD7-4A5B-9B3C-3EF9F2B6C3C5")!
        ),
        .init(
            fileName: "6 托福-乱序",
            title: "托福词汇乱序",
            sectionID: UUID(uuidString: "A2E1E629-189A-4D38-BC86-1B96E989F24C")!
        )
    ]

    static func loadAll() -> [WordSection] {
        descriptors.compactMap { descriptor in
            try? loadSection(descriptor: descriptor)
        }
    }

    private static func loadSection(descriptor: ResourceDescriptor) throws -> WordSection {
        let candidateURLs: [URL?] = [
            Bundle.main.url(forResource: descriptor.fileName, withExtension: resourceExtension),
            Bundle.main.url(forResource: descriptor.fileName, withExtension: resourceExtension, subdirectory: "Resources"),
            Bundle.main.resourceURL?.appendingPathComponent("\(descriptor.fileName).\(resourceExtension)"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/\(descriptor.fileName).\(resourceExtension)")
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
            id: descriptor.sectionID,
            title: descriptor.title,
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
    let session = AuthSession.preview
    let suiteName = "PreviewAuthSessionStore"
    let previewDefaults = UserDefaults(suiteName: suiteName)
    previewDefaults?.removePersistentDomain(forName: suiteName)
    let store = AuthSessionStore(userDefaults: previewDefaults ?? .standard, initialSession: session)
    return ContentView(session: session)
        .environmentObject(store)
}
