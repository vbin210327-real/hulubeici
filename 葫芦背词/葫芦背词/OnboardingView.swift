import SwiftUI
import UIKit

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case currentVocabulary
        case targetVocabulary
        case planSummary
    }

    private struct VocabularyOption: Identifiable, Equatable {
        let value: String
        let displayTitle: String
        let subtitle: String
        let icon: String

        var id: String { value }
    }

    private struct WelcomeFeatureCard: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: WelcomeFeatureIconType
        let accentColor: Color
        let isPlaceholder: Bool
        let visibility: WelcomeCardVisibility
        let column: WelcomeCardColumn
        let order: Int

        init(
            title: String,
            subtitle: String,
            icon: WelcomeFeatureIconType,
            accentColor: Color,
            isPlaceholder: Bool = false,
            visibility: WelcomeCardVisibility = .full,
            column: WelcomeCardColumn,
            order: Int
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.accentColor = accentColor
            self.isPlaceholder = isPlaceholder
            self.visibility = visibility
            self.column = column
            self.order = order
        }
    }

    private enum WelcomeCardVisibility {
        case full
        case peekLeft
        case peekRight
    }

    private enum WelcomeCardColumn {
        case left
        case center
        case right
    }

    fileprivate enum WelcomeFeatureIconType {
        case shuffle
        case progress
        case importWords
        case hideMeaning
    }

    var onContinue: () -> Void

    private let steps: [Step] = Step.allCases

    private let welcomeFeatureCards: [WelcomeFeatureCard] = [
        WelcomeFeatureCard(
            title: "",
            subtitle: "",
            icon: .shuffle,
            accentColor: Color(.systemGray4),
            isPlaceholder: true,
            visibility: .peekLeft,
            column: .left,
            order: 0
        ),
        WelcomeFeatureCard(
            title: "",
            subtitle: "",
            icon: .progress,
            accentColor: Color(.systemGray4),
            isPlaceholder: true,
            visibility: .peekLeft,
            column: .left,
            order: 1
        ),
        WelcomeFeatureCard(
            title: "不止是快",
            subtitle: "重新定义你的背单词方法",
            icon: .progress,
            accentColor: Color(red: 0.07, green: 0.69, blue: 0.54),
            visibility: .full,
            column: .center,
            order: 0
        ),
        WelcomeFeatureCard(
            title: "无需复习",
            subtitle: "挣脱艾宾浩斯束缚",
            icon: .hideMeaning,
            accentColor: Color(red: 0.17, green: 0.17, blue: 0.21),
            visibility: .full,
            column: .center,
            order: 1
        ),
        WelcomeFeatureCard(
            title: "长期记忆",
            subtitle: "重复的遍数就是你背的熟练度",
            icon: .shuffle,
            accentColor: Color(red: 0.26, green: 0.22, blue: 0.95),
            visibility: .peekRight,
            column: .right,
            order: 0
        ),
        WelcomeFeatureCard(
            title: "AI加持",
            subtitle: "一站式解决所有单词问题",
            icon: .importWords,
            accentColor: Color(red: 0.99, green: 0.58, blue: 0.26),
            visibility: .peekRight,
            column: .right,
            order: 1
        )
    ]

    private let targetVocabularyChoices: [VocabularyOption] = [
        VocabularyOption(value: "中考词汇量", displayTitle: "中考词汇量", subtitle: "约 1800 词", icon: "📗"),
        VocabularyOption(value: "高考词汇量", displayTitle: "高考词汇量", subtitle: "约 3500 词", icon: "📘"),
        VocabularyOption(value: "四六级词汇量", displayTitle: "四六级词汇量", subtitle: "约 5500 词", icon: "💻"),
        VocabularyOption(value: "其他", displayTitle: "其他", subtitle: "自定义目标", icon: "🌏")
    ]

    private let currentVocabularyChoices: [VocabularyOption] = [
        VocabularyOption(value: "少于 1000 个", displayTitle: "少于1000个", subtitle: "青铜词士", icon: "✏️"),
        VocabularyOption(value: "1000 - 3000 个", displayTitle: "1000-3000个", subtitle: "白银词客", icon: "📚"),
        VocabularyOption(value: "3000 - 6000 个", displayTitle: "3000-6000个", subtitle: "黄金词师", icon: "🧠"),
        VocabularyOption(value: "超过 6000 个", displayTitle: "6000以上", subtitle: "钻石词圣", icon: "🏆")
    ]

    @State private var currentStepIndex: Int = 0
    @State private var selectedCurrentVocabulary: String?
    @State private var selectedTargetVocabulary: String?

    private var currentStep: Step { steps[currentStepIndex] }
    private let stepRowSpacing: CGFloat = 16
    private let stepSectionSpacing: CGFloat = 24
    private let stepTopPadding: CGFloat = 10
    private let stepBottomPadding: CGFloat = 32
    private let stepChoicesTopPadding: CGFloat = 104
    private let stepHorizontalPadding: CGFloat = 24
    private let heroCardWidth: CGFloat = 240
    private let heroCardHeight: CGFloat = 140
    private let heroCardPeekFraction: CGFloat = 0.35
    private var heroBottomRowOffset: CGFloat { -(heroCardWidth / 6) }
    private let heroRowSpacing: CGFloat = 18
    private let heroRowVerticalSpacing: CGFloat = 12

    var body: some View {
        ZStack {
            backgroundLayer

            switch currentStep {
            case .welcome:
                welcomeLayout
            case .currentVocabulary:
                currentVocabularyLayout
            case .targetVocabulary:
                targetVocabularyLayout
            case .planSummary:
                planSummaryLayout
            }
        }
        .statusBarHidden(true)
    }

    private var backgroundLayer: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }

    private var welcomeLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            welcomeFeatureCardCluster
                .padding(.horizontal, 6)

            Spacer(minLength: 48)

            heroAppIconBadge

            VStack(spacing: 18) {
                Text("欢迎使用葫芦背词")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)

                Text("让背单词变得简单，从这里开始")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            Spacer()

            primaryActionButton

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 32)
        .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
    }

    private var horizontalPadding: CGFloat {
        currentStep == .welcome ? 32 : 24
    }

    private var welcomeFeatureCardCluster: some View {
        VStack(alignment: .center, spacing: heroRowVerticalSpacing) {
            heroRowView(order: 0)
            heroRowView(order: 1)
                .offset(x: heroBottomRowOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroCardHeight * 2 + heroRowVerticalSpacing)
    }

    private func heroRowView(order: Int) -> some View {
        let cards = welcomeFeatureCards
            .filter { $0.order == order }
            .sorted(by: columnSort)

        let contentWidth = heroCardWidth * CGFloat(cards.count) + heroRowSpacing * CGFloat(cards.count - 1)

        return GeometryReader { geo in
            let available = geo.size.width
            let overflow = max(contentWidth - available, 0)
            HStack(alignment: .top, spacing: heroRowSpacing) {
                ForEach(cards) { card in
                    welcomeFeatureCard(card)
                        .frame(width: heroCardWidth, height: heroCardHeight, alignment: .topLeading)
                }
            }
            .frame(width: max(contentWidth, available), alignment: .center)
            .offset(x: overflow > 0 ? -overflow / 2 : 0)
        }
        .frame(height: heroCardHeight)
    }

    private func cards(forOrder order: Int) -> [WelcomeFeatureCard] {
        welcomeFeatureCards.filter { $0.order == order }
    }

    private func columnSort(_ lhs: WelcomeFeatureCard, _ rhs: WelcomeFeatureCard) -> Bool {
        sortValue(for: lhs.column) < sortValue(for: rhs.column)
    }

    private func sortValue(for column: WelcomeCardColumn) -> Int {
        switch column {
        case .left: return 0
        case .center: return 1
        case .right: return 2
        }
    }

    @ViewBuilder
    private func welcomeFeatureCard(_ card: WelcomeFeatureCard) -> some View {
        let content: AnyView = {
            if card.isPlaceholder {
                return AnyView(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        
                )
            } else {
                return AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        WelcomeFeatureIcon(type: card.icon, accent: card.accentColor)
                            .frame(width: 46, height: 46)

                        Text(card.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.label))

                        Text(card.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                )
            }
        }()

        content
    }

    private var heroAppIconBadge: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return Group {
            if let iconImage = UIImage.appIcon {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "character.book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .foregroundStyle(Color.black)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.12), radius: 30, x: 0, y: 18)
    }

    private var currentVocabularyLayout: some View {
        stepLayout(
            title: "你目前的词汇量是多少？",
            subtitle: "这将用于后续背词速度的评估",
            choices: currentVocabularyChoices,
            selection: $selectedCurrentVocabulary
        )
    }

    private var targetVocabularyLayout: some View {
        stepLayout(
            title: "你的目标词汇量是多少？",
            subtitle: "帮你匹配合适的背词节奏",
            choices: targetVocabularyChoices,
            selection: $selectedTargetVocabulary
        )
    }



    private func stepLayout(
        title: String,
        subtitle: String,
        choices: [VocabularyOption],
        selection: Binding<String?>
    ) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: stepSectionSpacing) {
                        HStack(spacing: stepRowSpacing) {
                            if currentStepIndex > 0 {
                                circularBackButton
                            }

                            stepProgressBar
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 12) {
                            questionHeader(title: title, subtitle: subtitle)

                            optionsGroup(for: choices, selection: selection)
                                .padding(.top, stepChoicesTopPadding)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, stepHorizontalPadding)
                    .padding(.top, stepTopPadding)
                    .padding(.bottom, stepSectionSpacing)
                }

                primaryActionButton
                    .padding(.horizontal, stepHorizontalPadding)
                    .padding(.bottom, stepBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.easeInOut(duration: 0.28), value: currentStepIndex)
    }

    private func questionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func optionsGroup(
        for choices: [VocabularyOption],
        selection: Binding<String?>
    ) -> some View {
        VStack(spacing: 16) {
            ForEach(choices) { option in
                let isSelected = option.value == selection.wrappedValue
                vocabularyOptionRow(option: option, isSelected: isSelected) {
                    selection.wrappedValue = option.value
                }
            }
        }
        .frame(maxWidth: .infinity)
    }



    private func vocabularyOptionRow(option: VocabularyOption, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                    Text(option.icon)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(option.displayTitle)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.black)
                    Text(option.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.black.opacity(0.7))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.black : Color(red: 0.905, green: 0.925, blue: 0.907))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.black : Color.black.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .shadow(color: isSelected ? selectionShadow : Color.clear, radius: isSelected ? 12 : 0, x: 0, y: 8)
    }

    private var primaryActionButton: some View {
        GeometryReader { geo in
            let targetWidth = min(geo.size.width - 48, 360)

            Button(action: advanceStepOrFinish) {
                Text(primaryButtonTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryButtonDisabled ? Color.white.opacity(0.65) : Color.white)
                    .frame(width: targetWidth, height: 64)
                    .background(
                        Capsule(style: .continuous)
                            .fill(primaryButtonDisabled ? Color.black.opacity(0.28) : Color.black)
                    )
            }
            .buttonStyle(.plain)
            .disabled(primaryButtonDisabled)
            .opacity(primaryButtonDisabled ? 0.75 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 64)
    }

    private var planSummaryLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: stepRowSpacing) {
                if currentStepIndex > 0 {
                    circularBackButton
                }

                stepProgressBar
            }
            .padding(.horizontal, stepHorizontalPadding)
            .padding(.top, stepTopPadding)

            Spacer(minLength: 10)

            planSummaryView

            Spacer(minLength: 20)

            primaryActionButton
                .padding(.horizontal, stepHorizontalPadding)
                .padding(.bottom, stepBottomPadding)
        }
        .padding(.top, stepTopPadding)
    }

    private var primaryButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "开始使用"
        case .currentVocabulary, .targetVocabulary:
            return "继续"
        case .planSummary:
            return "继续"
        }
    }

    private var primaryButtonDisabled: Bool {
        switch currentStep {
        case .currentVocabulary:
            return selectedCurrentVocabulary == nil
        case .targetVocabulary:
            return selectedTargetVocabulary == nil
        case .planSummary, .welcome:
            return false
        }
    }

    private var progressIndicator: some View {
        let totalSegments = max(steps.count - 1, 1)
        let activeIndex = max(currentStepIndex - 1, 0)

        return HStack(spacing: 10) {
            ForEach(0..<totalSegments, id: \.self) { index in
                let isActive = currentStepIndex > 0 && index == activeIndex
                let isCompleted = currentStepIndex > 0 && index < activeIndex
                Capsule()
                    .fill((isActive || isCompleted) ? Color.black : Color.black.opacity(0.15))
                    .frame(width: isActive ? 28 : 16, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: currentStepIndex)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground).opacity(0.85))
        )
    }

    private var stepProgressBar: some View {
        GeometryReader { geometry in
            let trackWidth = max(geometry.size.width, 1)
            let minimumFraction: CGFloat = 0.08
            let clamped = max(min(progressFraction, 1), 0)
            let effectiveFraction = clamped == 0 ? minimumFraction : max(clamped, minimumFraction)
            let fillWidth = trackWidth * effectiveFraction

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(red: 0.86, green: 0.87, blue: 0.87))
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black)
                    .frame(width: fillWidth, height: 5)
            }
        }
        .frame(height: 5)
        .frame(maxWidth: .infinity)
        .frame(height: 44, alignment: .center)
    }

    private var circularBackButton: some View {
        Button(action: goToPreviousStep) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }
        }
        .buttonStyle(.plain)
    }

    private var progressFraction: CGFloat {
        guard steps.count > 1 else { return 1 }
        return CGFloat(currentStepIndex) / CGFloat(steps.count - 1)
    }

    private var selectionShadow: Color {
        Color(.label).opacity(0.25)
    }

    private func highlightedEncouragementText(_ summary: PlanSummary) -> Text {
        guard
            !summary.encouragement.isEmpty,
            !summary.highlightText.isEmpty,
            let range = summary.encouragement.range(of: summary.highlightText)
        else {
            var baseText = Text(summary.encouragement)

            if summary.showsSmileIcon {
                if let smileImage = smileIconImage(size: 18) {
                    baseText = baseText + Text(" ") + Text(Image(uiImage: smileImage)).baselineOffset(-4)
                }
            }

            return baseText
        }

        let prefix = String(summary.encouragement[..<range.lowerBound])
        let suffix = String(summary.encouragement[range.upperBound...])

        var text = Text(prefix)
            + Text(summary.highlightText)
                .foregroundStyle(Color(red: 1.0, green: 0.43, blue: 0.2))
                .fontWeight(.bold)
            + Text(suffix)

        if summary.showsSmileIcon {
            if let smileImage = smileIconImage(size: 18) {
                text = text + Text(" ") + Text(Image(uiImage: smileImage)).baselineOffset(-4)
            }
        }

        return text
    }

    private func smileIconImage(size: CGFloat) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)

            let path = SmileIconShape().path(in: rect)
            UIColor.label.setFill()
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()
        }
    }

    private func goToPreviousStep() {
        guard currentStepIndex > 0 else { return }
        Haptic.trigger(.light)
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStepIndex = max(0, currentStepIndex - 1)
        }
    }

    private func advanceStepOrFinish() {
        Haptic.trigger(.medium)
        if currentStepIndex < steps.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.4)) {
                currentStepIndex += 1
            }
        } else {
            onContinue()
        }
    }

    private var planSummaryView: some View {
        let summary = planSummary

        let styledText = highlightedEncouragementText(summary)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color(.label))
            .multilineTextAlignment(.center)
            .lineSpacing(6)

        return styledText
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
    }

    private var planSummary: PlanSummary {
        guard
            let currentSelection = selectedCurrentVocabulary,
            let targetSelection = selectedTargetVocabulary,
            let targetWords = vocabularyWordCount(forTarget: targetSelection)
        else {
            return PlanSummary.empty
        }

        let currentWords = vocabularyWordCount(forCurrent: currentSelection)
        let additionalWords = max(targetWords - currentWords, 0)

        if targetSelection == "其他" {
            let encouragement = "没关系，我们还有更多的词书等待你探索，准备好开始葫芦背书之旅了吗？"
            return PlanSummary(encouragement: encouragement, highlightText: "", showsSmileIcon: true)
        }

        if additionalWords <= 0 {
            let encouragement = "预计新增单词0词，可以按照葫芦背书法复习巩固保持熟练度，或者开始学习新的单词：）"
            return PlanSummary(encouragement: encouragement, highlightText: "", showsSmileIcon: false)
        }

        let introductionDays = max(Int(ceil(Double(additionalWords) / 1000.0)), 1)
        let reviewDays = introductionDays * 10
        let totalDays = introductionDays + reviewDays

        let durationText = formattedDuration(days: totalDays)
        let encouragement = "预计新增单词\(additionalWords)个，这个目标并不难实现，按照葫芦背书法最快仅需\(durationText)就能掌握90%的\(targetSelection)（约\(targetWords)词）"

        return PlanSummary(encouragement: encouragement, highlightText: durationText, showsSmileIcon: false)
    }

    private func formattedDuration(days: Int) -> String {
        if days >= 365 {
            let years = Double(days) / 365.0
            return years < 1.5 ? "约1年" : "约\(Int(round(years)))年"
        }

        if days >= 60 {
            let months = Double(days) / 30.0
            return "约\(Int(round(months)))个月"
        }

        if days >= 14 {
            let weeks = Double(days) / 7.0
            let formattedWeeks = String(format: "%.1f", weeks)
            return "约\(formattedWeeks)周"
        }

        return "约\(days)天"
    }

    private func vocabularyWordCount(forCurrent selection: String) -> Int {
        switch selection {
        case "少于 1000 个": return 500
        case "1000 - 3000 个": return 2000
        case "3000 - 6000 个": return 4500
        case "超过 6000 个": return 6500
        default: return 3000
        }
    }

    private func vocabularyWordCount(forTarget selection: String) -> Int? {
        switch selection {
        case "中考词汇量": return 1800
        case "高考词汇量": return 3500
        case "四六级词汇量": return 5500
        case "考研词汇量": return 9000
        case "其他": return 3000
        default: return nil
        }
    }

private struct PlanSummary {
    let encouragement: String
    let highlightText: String
    let showsSmileIcon: Bool

    static let empty = PlanSummary(encouragement: "", highlightText: "", showsSmileIcon: false)
}

private struct PlanSummarySmileIcon: View {
    var body: some View {
        SmileIconShape()
            .fill(Color(.label))
    }
}

private struct SmileIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let baseSize: CGFloat = 96.433
        let scale = min(rect.width, rect.height) / baseSize
        let offsetX = rect.midX - (baseSize / 2) * scale
        let offsetY = rect.midY - (baseSize / 2) * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: offsetX + x * scale,
                y: offsetY + y * scale
            )
        }

        var path = Path()

        // Left eye
        path.move(to: point(24.82, 48.678))
        path.addCurve(
            to: point(34.652, 33.867),
            control1: point(30.242, 48.678),
            control2: point(34.652, 42.034)
        )
        path.addCurve(
            to: point(24.82, 19.058),
            control1: point(34.652, 25.702),
            control2: point(30.242, 19.058)
        )
        path.addCurve(
            to: point(14.987, 33.867),
            control1: point(19.398, 19.058),
            control2: point(14.987, 25.702)
        )
        path.addCurve(
            to: point(24.82, 48.678),
            control1: point(14.987, 42.034),
            control2: point(19.399, 48.678)
        )
        path.closeSubpath()

        // Right eye
        path.move(to: point(71.606, 48.678))
        path.addCurve(
            to: point(81.439, 33.867),
            control1: point(77.028, 48.678),
            control2: point(81.439, 42.034)
        )
        path.addCurve(
            to: point(71.606, 19.058),
            control1: point(81.439, 25.702),
            control2: point(77.028, 19.058)
        )
        path.addCurve(
            to: point(61.775, 33.867),
            control1: point(66.185, 19.058),
            control2: point(61.775, 25.702)
        )
        path.addCurve(
            to: point(71.606, 48.678),
            control1: point(61.775, 42.034),
            control2: point(66.186, 48.678)
        )
        path.closeSubpath()

        // Smile curve
        path.move(to: point(95.855, 55.806))
        path.addCurve(
            to: point(93.57, 55.406),
            control1: point(95.255, 55.201),
            control2: point(94.339, 55.036)
        )
        path.addCurve(
            to: point(48.214, 64.53),
            control1: point(81.232, 61.29),
            control2: point(65.125, 64.53)
        )
        path.addCurve(
            to: point(2.86, 55.407),
            control1: point(31.307, 64.53),
            control2: point(15.199, 61.29)
        )
        path.addCurve(
            to: point(0.576, 55.807),
            control1: point(2.09, 55.04),
            control2: point(1.172, 55.202)
        )
        path.addCurve(
            to: point(0.207, 58.097),
            control1: point(-0.023, 56.413),
            control2: point(-0.171, 57.333)
        )
        path.addCurve(
            to: point(48.215, 77.374),
            control1: point(5.813, 69.448),
            control2: point(25.556, 77.374)
        )
        path.addCurve(
            to: point(96.227, 58.095),
            control1: point(70.883, 77.374),
            control2: point(90.627, 69.445)
        )
        path.addCurve(
            to: point(95.855, 55.806),
            control1: point(96.603, 57.332),
            control2: point(96.453, 56.411)
        )
        path.closeSubpath()

        return path
    }
}
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onContinue: {})
    }
}

private struct WelcomeFeatureIcon: View {
    let type: OnboardingView.WelcomeFeatureIconType
    let accent: Color

    var body: some View {
        let strokeColor: Color = {
            switch type {
            case .progress, .importWords, .shuffle:
                return Color.black
            default:
                return accent
            }
        }()
        let strokeStyle = StrokeStyle(
            lineWidth: lineWidth(for: type),
            lineCap: .round,
            lineJoin: .round
        )

        shapeForType(type)
            .stroke(strokeColor, style: strokeStyle)
    }

    private func shapeForType(_ type: OnboardingView.WelcomeFeatureIconType) -> AnyShape {
        switch type {
        case .shuffle:
            return AnyShape(WelcomeShuffleIconShape())
        case .progress:
            return AnyShape(WelcomeFlameIconShape())
        case .importWords:
            return AnyShape(WelcomeImportIconShape())
        case .hideMeaning:
            return AnyShape(WelcomeMaskIconShape())
        }
    }

    private func lineWidth(for type: OnboardingView.WelcomeFeatureIconType) -> CGFloat {
        switch type {
        case .hideMeaning:
            return 1.5
        case .importWords:
            return 1.2
        case .shuffle:
            return 1.1
        default:
            return 1.8
        }
    }
}

private struct AnyShape: Shape {
    private let build: @Sendable (CGRect) -> Path

    init<S: Shape & Sendable>(_ shape: S) {
        self.build = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        build(rect)
    }
}

private struct WelcomeShuffleIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale,
                    y: offsetY + y * scale)
        }

        var path = Path()
        path.move(to: point(22.55952, 10.87488))
        path.addCurve(to: point(21.48288, 8.61552),
                              control1: point(22.55952, 9.99264),
                              control2: point(22.16136, 9.16584))
        path.addCurve(to: point(21.52704, 8.20608),
                              control1: point(21.5124, 8.47464),
                              control2: point(21.52704, 8.33928))
        path.addCurve(to: point(19.65864, 6.0372),
                              control1: point(21.52704, 7.10712),
                              control2: point(20.7144, 6.1944))
        path.addCurve(to: point(19.6944, 5.66376),
                              control1: point(19.68288, 5.91096),
                              control2: point(19.6944, 5.78712))
        path.addCurve(to: point(17.6172, 3.47712),
                              control1: point(19.6944, 4.49376),
                              control2: point(18.77232, 3.53784))
        path.addCurve(to: point(17.55912, 3.47136),
                              control1: point(17.59824, 3.474),
                              control2: point(17.57904, 3.47136))
        path.addCurve(to: point(17.53032, 3.4728),
                              control1: point(17.54952, 3.47136),
                              control2: point(17.54016, 3.47256))
        path.addCurve(to: point(17.50152, 3.47136),
                              control1: point(17.52072, 3.47256),
                              control2: point(17.51136, 3.47136))
        path.addCurve(to: point(17.16408, 3.5016),
                              control1: point(17.3916, 3.47136),
                              control2: point(17.28096, 3.4812))
        path.addCurve(to: point(14.8992, 1.6236),
                              control1: point(16.96104, 2.4252),
                              control2: point(16.02336, 1.6236))
        path.addCurve(to: point(12.58752, 3.93552),
                              control1: point(13.62456, 1.6236),
                              control2: point(12.58752, 2.66064))
        path.addLine(to: point(12.58752, 19.75584))
        path.addCurve(to: point(15.51336, 22.68168),
                              control1: point(12.58752, 21.36936),
                              control2: point(13.90008, 22.68168))
        path.addCurve(to: point(18.0684, 21.18264),
                              control1: point(16.58376, 22.68168),
                              control2: point(17.55528, 22.10256))
        path.addCurve(to: point(18.40464, 21.23016),
                              control1: point(18.18336, 21.2076),
                              control2: point(18.29376, 21.22296))
        path.addCurve(to: point(20.30688, 20.58384),
                              control1: point(19.10136, 21.27456),
                              control2: point(19.77984, 21.04632))
        path.addCurve(to: point(21.19488, 18.78144),
                              control1: point(20.83392, 20.12136),
                              control2: point(21.14928, 19.48128))
        path.addCurve(to: point(21.09816, 17.90832),
                              control1: point(21.21384, 18.48984),
                              control2: point(21.1812, 18.19728))
        path.addCurve(to: point(22.54464, 15.11928),
                              control1: point(22.0092, 17.26248),
                              control2: point(22.54464, 16.23984))
        path.addCurve(to: point(21.71784, 12.90552),
                              control1: point(22.54464, 14.30688),
                              control2: point(22.25208, 13.52688))
        path.addCurve(to: point(22.55952, 10.87488),
                              control1: point(22.25544, 12.3612),
                              control2: point(22.55952, 11.63304))
        path.closeSubpath()
        path.move(to: point(21.82512, 15.11976))
        path.addCurve(to: point(20.79432, 17.23632),
                              control1: point(21.82512, 15.95592),
                              control2: point(21.44544, 16.72296))
        path.addCurve(to: point(18.53184, 15.97944),
                              control1: point(20.3124, 16.46928),
                              control2: point(19.45752, 15.97944))
        path.addCurve(to: point(18.17184, 16.33944),
                              control1: point(18.33312, 15.97944),
                              control2: point(18.17184, 16.14072))
        path.addCurve(to: point(18.53184, 16.69944),
                              control1: point(18.17184, 16.53816),
                              control2: point(18.33312, 16.69944))
        path.addCurve(to: point(20.35152, 17.94936),
                              control1: point(19.33368, 16.69944),
                              control2: point(20.064, 17.20176))
        path.addCurve(to: point(20.47656, 18.73512),
                              control1: point(20.44992, 18.21048),
                              control2: point(20.4936, 18.47472))
        path.addCurve(to: point(19.83216, 20.04288),
                              control1: point(20.44344, 19.24296),
                              control2: point(20.21472, 19.70736))
        path.addCurve(to: point(18.45168, 20.51184),
                              control1: point(19.4496, 20.37864),
                              control2: point(18.95832, 20.54544))
        path.addCurve(to: point(17.98776, 20.41536),
                              control1: point(18.30912, 20.50248),
                              control2: point(18.16176, 20.47176))
        path.addCurve(to: point(17.54472, 20.61696),
                              control1: point(17.81016, 20.35728),
                              control2: point(17.61792, 20.44512))
        path.addCurve(to: point(15.51312, 21.96192),
                              control1: point(17.19792, 21.43392),
                              control2: point(16.4004, 21.96192))
        path.addCurve(to: point(13.30728, 19.75608),
                              control1: point(14.2968, 21.96192),
                              control2: point(13.30728, 20.9724))
        path.addLine(to: point(13.30728, 3.93576))
        path.addCurve(to: point(14.89896, 2.34384),
                              control1: point(13.30728, 3.05808),
                              control2: point(14.02128, 2.34384))
        path.addCurve(to: point(16.47288, 3.76176),
                              control1: point(15.71448, 2.34384),
                              control2: point(16.38552, 2.95872))
        path.addCurve(to: point(15.366, 5.664),
                              control1: point(15.81264, 4.14),
                              control2: point(15.366, 4.85016))
        path.addCurve(to: point(15.726, 6.024),
                              control1: point(15.366, 5.86296),
                              control2: point(15.52728, 6.024))
        path.addCurve(to: point(16.086, 5.664),
                              control1: point(15.92472, 6.024),
                              control2: point(16.086, 5.86296))
        path.addCurve(to: point(17.52984, 4.1928),
                              control1: point(16.086, 4.86168),
                              control2: point(16.73136, 4.2084))
        path.addCurve(to: point(18.97368, 5.66376),
                              control1: point(18.32832, 4.2084),
                              control2: point(18.97368, 4.86168))
        path.addCurve(to: point(18.88752, 6.1368),
                              control1: point(18.97368, 5.81304),
                              control2: point(18.9456, 5.9676))
        path.addCurve(to: point(18.86808, 6.2604),
                              control1: point(18.87384, 6.17664),
                              control2: point(18.86736, 6.2184))
        path.addCurve(to: point(18.86976, 6.288),
                              control1: point(18.86832, 6.27024),
                              control2: point(18.8688, 6.27936))
        path.addCurve(to: point(18.86736, 6.2964),
                              control1: point(18.86832, 6.29304),
                              control2: point(18.86736, 6.2964))
        path.addCurve(to: point(18.9396, 6.61512),
                              control1: point(18.83904, 6.408),
                              control2: point(18.86592, 6.52656))
        path.addCurve(to: point(19.23984, 6.74424),
                              control1: point(19.01328, 6.70368),
                              control2: point(19.1232, 6.75168))
        path.addCurve(to: point(19.33392, 6.7332),
                              control1: point(19.2648, 6.74256),
                              control2: point(19.28976, 6.73944))
        path.addCurve(to: point(20.80656, 8.20584),
                              control1: point(20.14584, 6.7332),
                              control2: point(20.80656, 7.39392))
        path.addCurve(to: point(20.72928, 8.6496),
                              control1: point(20.80656, 8.34312),
                              control2: point(20.78184, 8.484))
        path.addCurve(to: point(20.87112, 9.0576),
                              control1: point(20.68056, 8.802),
                              control2: point(20.7384, 8.96832))
        path.addCurve(to: point(21.83448, 10.79568),
                              control1: point(21.45528, 9.45096),
                              control2: point(21.80928, 10.09656))
        path.addCurve(to: point(21.83424, 10.79856),
                              control1: point(21.83448, 10.79664),
                              control2: point(21.83424, 10.7976))
        path.addCurve(to: point(19.64496, 12.98808),
                              control1: point(21.83424, 12.00576),
                              control2: point(20.85216, 12.98808))
        path.addCurve(to: point(17.45544, 10.79856),
                              control1: point(18.43776, 12.98808),
                              control2: point(17.45544, 12.00576))
        path.addCurve(to: point(17.09544, 10.43856),
                              control1: point(17.45544, 10.5996),
                              control2: point(17.29416, 10.43856))
        path.addCurve(to: point(16.73544, 10.79856),
                              control1: point(16.89672, 10.43856),
                              control2: point(16.73544, 10.5996))
        path.addCurve(to: point(19.64496, 13.70808),
                              control1: point(16.73544, 12.40296),
                              control2: point(18.04056, 13.70808))
        path.addCurve(to: point(21.1104, 13.30776),
                              control1: point(20.17968, 13.70808),
                              control2: point(20.67936, 13.56048))
        path.addCurve(to: point(21.82512, 15.11976),
                              control1: point(21.5712, 13.80936),
                              control2: point(21.82512, 14.45088))
        path.closeSubpath()
        path.move(to: point(9.16296, 1.62384))
        path.addCurve(to: point(6.89856, 3.50184),
                              control1: point(8.0388, 1.62384),
                              control2: point(7.10136, 2.42544))
        path.addCurve(to: point(6.56088, 3.4716),
                              control1: point(6.78144, 3.48144),
                              control2: point(6.6708, 3.4716))
        path.addCurve(to: point(6.53208, 3.47304),
                              control1: point(6.55128, 3.4716),
                              control2: point(6.54192, 3.4728))
        path.addCurve(to: point(6.50328, 3.4716),
                              control1: point(6.52248, 3.4728),
                              control2: point(6.51312, 3.4716))
        path.addCurve(to: point(6.4452, 3.47736),
                              control1: point(6.48336, 3.4716),
                              control2: point(6.46416, 3.47424))
        path.addCurve(to: point(4.36824, 5.664),
                              control1: point(5.29008, 3.53808),
                              control2: point(4.36824, 4.494))
        path.addCurve(to: point(4.404, 6.03744),
                              control1: point(4.36824, 5.78736),
                              control2: point(4.38, 5.9112))
        path.addCurve(to: point(2.5356, 8.20632),
                              control1: point(3.34824, 6.19464),
                              control2: point(2.5356, 7.10736))
        path.addCurve(to: point(2.57976, 8.61576),
                              control1: point(2.5356, 8.33928),
                              control2: point(2.55024, 8.47464))
        path.addCurve(to: point(1.50312, 10.87512),
                              control1: point(1.90128, 9.16608),
                              control2: point(1.50312, 9.99288))
        path.addCurve(to: point(2.34432, 12.90624),
                              control1: point(1.50312, 11.63328),
                              control2: point(1.80696, 12.36144))
        path.addCurve(to: point(1.51728, 15.12),
                              control1: point(1.80984, 13.5276),
                              control2: point(1.51728, 14.3076))
        path.addCurve(to: point(2.96376, 17.90904),
                              control1: point(1.51728, 16.24056),
                              control2: point(2.05272, 17.26296))
        path.addCurve(to: point(2.86728, 18.7824),
                              control1: point(2.88048, 18.198),
                              control2: point(2.84808, 18.49056))
        path.addCurve(to: point(3.75504, 20.58456),
                              control1: point(2.91288, 19.482),
                              control2: point(3.228, 20.12208))
        path.addCurve(to: point(5.65728, 21.23088),
                              control1: point(4.28208, 21.04728),
                              control2: point(4.95864, 21.27552))
        path.addCurve(to: point(5.99328, 21.18312),
                              control1: point(5.76648, 21.22368),
                              control2: point(5.87784, 21.20784))
        path.addCurve(to: point(8.54832, 22.6824),
                              control1: point(6.5064, 22.10328),
                              control2: point(7.47792, 22.6824))
        path.addCurve(to: point(11.47416, 19.75656),
                              control1: point(10.1616, 22.6824),
                              control2: point(11.47416, 21.36984))
        path.addLine(to: point(11.47416, 3.93576))
        path.addCurve(to: point(9.16296, 1.62384),
                              control1: point(11.47464, 2.66088),
                              control2: point(10.4376, 1.62384))
        path.closeSubpath()
        path.move(to: point(10.75464, 19.75608))
        path.addCurve(to: point(8.5488, 21.96192),
                              control1: point(10.75464, 20.9724),
                              control2: point(9.76512, 21.96192))
        path.addCurve(to: point(6.51744, 20.61696),
                              control1: point(7.66152, 21.96192),
                              control2: point(6.864, 21.43392))
        path.addCurve(to: point(6.186, 20.3976),
                              control1: point(6.4596, 20.48088),
                              control2: point(6.32712, 20.3976))
        path.addCurve(to: point(6.0744, 20.41536),
                              control1: point(6.14904, 20.3976),
                              control2: point(6.11136, 20.40312))
        path.addCurve(to: point(5.61048, 20.51184),
                              control1: point(5.90064, 20.47176),
                              control2: point(5.75328, 20.50248))
        path.addCurve(to: point(4.23024, 20.04288),
                              control1: point(5.10192, 20.5452),
                              control2: point(4.61256, 20.3784))
        path.addCurve(to: point(3.58584, 18.73512),
                              control1: point(3.84768, 19.70736),
                              control2: point(3.61896, 19.24296))
        path.addCurve(to: point(3.72936, 17.89632),
                              control1: point(3.5676, 18.45672),
                              control2: point(3.61584, 18.17448))
        path.addCurve(to: point(3.732, 17.8836),
                              control1: point(3.73104, 17.89224),
                              control2: point(3.73056, 17.88768))
        path.addCurve(to: point(5.55528, 16.69488),
                              control1: point(4.05408, 17.15016),
                              control2: point(4.746, 16.69488))
        path.addCurve(to: point(5.91528, 16.33488),
                              control1: point(5.75424, 16.69488),
                              control2: point(5.91528, 16.5336))
        path.addCurve(to: point(5.55528, 15.97488),
                              control1: point(5.91528, 16.13616),
                              control2: point(5.75424, 15.97488))
        path.addCurve(to: point(3.26376, 17.23224),
                              control1: point(4.61016, 15.97488),
                              control2: point(3.75504, 16.45656))
        path.addCurve(to: point(2.23728, 15.11976),
                              control1: point(2.61552, 16.71888),
                              control2: point(2.23728, 15.95376))
        path.addCurve(to: point(2.952, 13.308),
                              control1: point(2.23728, 14.45088),
                              control2: point(2.49168, 13.80936))
        path.addCurve(to: point(4.41768, 13.70832),
                              control1: point(3.38304, 13.56072),
                              control2: point(3.88296, 13.70832))
        path.addCurve(to: point(7.3272, 10.7988),
                              control1: point(6.02208, 13.70832),
                              control2: point(7.3272, 12.4032))
        path.addCurve(to: point(6.9672, 10.4388),
                              control1: point(7.3272, 10.59984),
                              control2: point(7.16616, 10.4388))
        path.addCurve(to: point(6.6072, 10.7988),
                              control1: point(6.76824, 10.4388),
                              control2: point(6.6072, 10.59984))
        path.addCurve(to: point(4.41768, 12.98832),
                              control1: point(6.6072, 12.006),
                              control2: point(5.62512, 12.98832))
        path.addCurve(to: point(2.22816, 10.7988),
                              control1: point(3.21024, 12.98832),
                              control2: point(2.22816, 12.006))
        path.addCurve(to: point(2.22792, 10.79736),
                              control1: point(2.22816, 10.79832),
                              control2: point(2.22792, 10.79784))
        path.addCurve(to: point(3.19104, 9.05784),
                              control1: point(2.25264, 10.09776),
                              control2: point(2.60664, 9.45168))
        path.addCurve(to: point(3.33288, 8.65008),
                              control1: point(3.32376, 8.96856),
                              control2: point(3.38136, 8.80248))
        path.addCurve(to: point(3.2556, 8.20608),
                              control1: point(3.28008, 8.48424),
                              control2: point(3.2556, 8.34336))
        path.addCurve(to: point(4.7424, 6.73608),
                              control1: point(3.2556, 7.39584),
                              control2: point(3.91344, 6.73608))
        path.addCurve(to: point(4.74768, 6.73608),
                              control1: point(4.74408, 6.73608),
                              control2: point(4.746, 6.73608))
        path.addCurve(to: point(4.82232, 6.74424),
                              control1: point(4.7724, 6.73944),
                              control2: point(4.79712, 6.74256))
        path.addCurve(to: point(5.12328, 6.61416),
                              control1: point(4.93872, 6.75144),
                              control2: point(5.04984, 6.7032))
        path.addCurve(to: point(5.19384, 6.294),
                              control1: point(5.19696, 6.52488),
                              control2: point(5.22336, 6.40584))
        path.addCurve(to: point(5.19192, 6.28656),
                              control1: point(5.19384, 6.29376),
                              control2: point(5.19312, 6.29064))
        path.addCurve(to: point(5.1936, 6.26376),
                              control1: point(5.19264, 6.27816),
                              control2: point(5.19336, 6.27048))
        path.addCurve(to: point(5.17416, 6.1368),
                              control1: point(5.1948, 6.22056),
                              control2: point(5.18832, 6.1776))
        path.addCurve(to: point(5.088, 5.66352),
                              control1: point(5.11608, 5.96712),
                              control2: point(5.088, 5.81232))
        path.addCurve(to: point(6.53184, 4.19256),
                              control1: point(5.088, 4.86144),
                              control2: point(5.73312, 4.20792))
        path.addCurve(to: point(7.97568, 5.66376),
                              control1: point(7.33056, 4.20816),
                              control2: point(7.97568, 4.86144))
        path.addCurve(to: point(8.33568, 6.02376),
                              control1: point(7.97568, 5.86272),
                              control2: point(8.13672, 6.02376))
        path.addCurve(to: point(8.69568, 5.66376),
                              control1: point(8.53464, 6.02376),
                              control2: point(8.69568, 5.86272))
        path.addCurve(to: point(7.5888, 3.76152),
                              control1: point(8.69568, 4.84992),
                              control2: point(8.24904, 4.13976))
        path.addCurve(to: point(9.16272, 2.3436),
                              control1: point(7.67616, 2.95848),
                              control2: point(8.3472, 2.3436))
        path.addCurve(to: point(10.7544, 3.93552),
                              control1: point(10.0404, 2.3436),
                              control2: point(10.7544, 3.05784))
        path.addLine(to: point(10.7544, 19.75608))
        path.closeSubpath()
        return path
    }
}

private struct WelcomeFlameIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: offsetX + CGFloat(x) * scale,
                    y: offsetY + CGFloat(y) * scale)
        }

        var path = Path()

        path.move(to: point(15.362, 5.214))
        path.addCurve(to: point(20.0663395571, 14.4669082472),
                      control1: point(18.9165201612, 6.802375515),
                      control2: point(20.8773149091, 10.659038852))
        path.addCurve(to: point(12.0, 21.0),
                      control1: point(19.2553642051, 18.2747776425),
                      control2: point(15.8932692613, 20.9978064207))
        path.addCurve(to: point(4.4129426055, 15.9916297345),
                      control1: point(8.696307351, 21.000240242),
                      control2: point(5.7110454274, 19.0296083784))
        path.addCurve(to: point(6.038, 7.047),
                      control1: point(3.1148397836, 12.9536510907),
                      control2: point(3.7542473577, 9.4342283187))
        path.addCurve(to: point(9.0, 9.601),
                      control1: point(6.8074209645, 8.1224632868),
                      control2: point(7.8230369117, 8.998183452))
        path.addCurve(to: point(12.361, 2.734),
                      control1: point(9.0417347869, 6.9256830061),
                      control2: point(10.2738864893, 4.4082222086))
        path.addCurve(to: point(15.361, 5.214),
                      control1: point(13.1477488571, 3.7891918504),
                      control2: point(14.1766633305, 4.6397611485))
        path.closeSubpath()

        path.move(to: point(12.0, 18.0))
        path.addCurve(to: point(15.7479765049, 14.4980214073),
                      control1: point(13.9771735188, 18.0032621325),
                      control2: point(15.6172106557, 16.4708686031))
        path.addCurve(to: point(12.495, 10.532),
                      control1: point(15.8787423541, 12.5251742116),
                      control2: point(14.4553069974, 10.7897251272))
        path.addCurve(to: point(10.57, 14.079),
                      control1: point(11.4623680273, 11.4560752116),
                      control2: point(10.782067801, 12.7095946416))
        path.addCurve(to: point(8.437, 13.078),
                      control1: point(9.7996062118, 13.8902196966),
                      control2: point(9.0745101832, 13.5499378754))
        path.addCurve(to: point(8.9615136968, 16.4489232422),
                      control1: point(8.0610256977, 14.2207277452),
                      control2: point(8.2561053967, 15.4744580013))
        path.addCurve(to: point(12.0, 18.0),
                      control1: point(9.666921997, 17.4233884831),
                      control2: point(10.7970106811, 18.0002725357))
        path.closeSubpath()

        return path
    }
}

private struct WelcomeImportIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()

        path.move(to: point(13.128234375, 0))
        path.addCurve(to: point(4.16653125, 8.8396875),
                      control1: point(8.2273125, 0),
                      control2: point(4.23253125, 3.954140625))
        path.addLine(to: point(1.909265625, 15.33075))
        path.addLine(to: point(4.1656875, 15.33075))
        path.addLine(to: point(4.1656875, 20.1675))
        path.addLine(to: point(8.54446875, 20.1675))
        path.addLine(to: point(8.54446875, 24))
        path.addLine(to: point(18.835640625, 24))
        path.addLine(to: point(18.8356875, 24))
        path.addLine(to: point(18.8356875, 15.872203125))
        path.addCurve(to: point(21.128015625, 13.00696875),
                      control1: point(19.784671875, 15.086578125),
                      control2: point(20.5730625, 14.102296875))
        path.addCurve(to: point(22.090734375, 8.9625),
                      control1: point(21.766828125, 11.745984375),
                      control2: point(22.090734375, 10.385296875))
        path.addCurve(to: point(13.128234375, 0),
                      control1: point(22.090734375, 4.020609375),
                      control2: point(18.070171875, 0))
        path.closeSubpath()

        path.move(to: point(13.25503125, 2.3775))
        path.addCurve(to: point(9.755859375, 3.30675),
                      control1: point(12.02053125, 2.354578125),
                      control2: point(10.81096875, 2.6754375))
        path.addCurve(to: point(8.039484375, 6.35334375),
                      control1: point(8.675953125, 3.952921875),
                      control2: point(8.034328125, 5.09184375))
        path.addCurve(to: point(9.79284375, 9.404296875),
                      control1: point(8.0446875, 7.62196875),
                      control2: point(8.70009375, 8.76253125))
        path.addLine(to: point(14.3686875, 12.09196875))
        path.addCurve(to: point(16.16859375, 12.586078125),
                      control1: point(14.929125, 12.421125),
                      control2: point(15.54815625, 12.586078125))
        path.addCurve(to: point(17.89275, 12.137484375),
                      control1: point(16.758703125, 12.586078125),
                      control2: point(17.350078125, 12.436734375))
        path.addCurve(to: point(19.71103125, 9.1779375),
                      control1: point(18.9915, 11.531671875),
                      control2: point(19.6711875, 10.425328125))
        path.addCurve(to: point(19.714265625, 9.01415625),
                      control1: point(19.71271875, 9.12346875),
                      control2: point(19.71384375, 9.068859375))
        path.addLine(to: point(19.714265625, 9.01378125))
        path.addCurve(to: point(13.25503125, 2.3775),
                      control1: point(19.74140625, 5.422453125),
                      control2: point(16.843828125, 2.445515625))
        path.closeSubpath()

        path.move(to: point(18.28584375, 9.132421875))
        path.addCurve(to: point(17.20415625, 10.888828125),
                      control1: point(18.26221875, 9.87178125),
                      control2: point(17.857875, 10.52840625))
        path.addCurve(to: point(15.09075, 10.8624375),
                      control1: point(16.53609375, 11.25721875),
                      control2: point(15.746015625, 11.247375))
        path.addLine(to: point(10.51490625, 8.1748125))
        path.addCurve(to: point(9.465234375, 6.347484375),
                      control1: point(9.860765625, 7.790625),
                      control2: point(9.468328125, 7.107515625))
        path.addCurve(to: point(10.48790625, 4.53028125),
                      control1: point(9.462140625, 5.594671875),
                      control2: point(9.844453125, 4.9153125))
        path.addCurve(to: point(13.129546875, 3.802125),
                      control1: point(11.285625, 4.052953125),
                      control2: point(12.196875, 3.802125))
        path.addCurve(to: point(13.227984375, 3.803015625),
                      control1: point(13.162359375, 3.802125),
                      control2: point(13.195171875, 3.802453125))
        path.addCurve(to: point(18.288421875, 9.00290625),
                      control1: point(16.039640625, 3.8563125),
                      control2: point(18.30975, 6.188953125))
        path.addCurve(to: point(18.28584375, 9.132421875),
                      control1: point(18.288046875, 9.04621875),
                      control2: point(18.287203125, 9.0894375))
        path.closeSubpath()

        return path
    }
}

private struct WelcomeMaskIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.midX - 12.0 * scale
        let offsetY = rect.midY - 12.0 * scale

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: offsetX + CGFloat(x) * scale,
                    y: offsetY + CGFloat(y) * scale)
        }

        var path = Path()

        path.move(to: point(15.59, 14.37))
        path.addCurve(to: point(14.45590674953, 19.473237861417),
                      control1: point(16.01186095659, 16.155004827922),
                      control2: point(15.594086887585, 18.034921180107))
        path.addCurve(to: point(9.75, 21.75),
                      control1: point(13.317726611474, 20.911554542726),
                      control2: point(11.58417797225, 21.750261749913))
        path.addLine(to: point(9.75, 16.95))

        path.move(to: point(15.59, 14.37))
        path.addCurve(to: point(21.75, 2.25),
                      control1: point(19.46398142679, 11.548065471907),
                      control2: point(21.753780994543, 7.042810478209))
        path.addCurve(to: point(9.631, 8.41),
                      control1: point(16.957541941238, 2.246539031545),
                      control2: point(12.452727128178, 4.536303801613))

        path.move(to: point(15.591, 14.37))
        path.addCurve(to: point(9.75, 16.95),
                      control1: point(13.852905712675, 15.641275935138),
                      control2: point(11.8603146835, 16.521413729227))

        path.move(to: point(9.631, 8.41))
        path.addCurve(to: point(4.527072317213, 9.543611348177),
                      control1: point(7.845851653729, 7.987782295987),
                      control2: point(5.965637936339, 8.405388449424))
        path.addCurve(to: point(2.25, 14.25),
                      control1: point(3.088506698088, 10.68183424693),
                      control2: point(2.249665932229, 12.415600289965))
        path.addLine(to: point(7.05, 14.25))

        path.move(to: point(9.631, 8.41))
        path.addCurve(to: point(7.051, 14.25),
                      control1: point(8.359882531251, 10.147814719474),
                      control2: point(7.479753404135, 12.140044991707))

        path.move(to: point(9.75, 16.95))
        path.addCurve(to: point(9.439, 17.01),
                      control1: point(9.647, 16.971),
                      control2: point(9.543, 16.991))
        path.addCurve(to: point(6.991, 14.562),
                      control1: point(8.531787588022, 16.290616794777),
                      control2: point(7.710383205223, 15.469212411978))
        path.addCurve(to: point(7.051, 14.25),
                      control1: point(7.009890589602, 14.457789716754),
                      control2: point(7.029891726373, 14.353783805549))

        path.move(to: point(4.811, 16.64))
        path.addCurve(to: point(3.054, 20.946),
                      control1: point(3.470256111478, 17.636997279029),
                      control2: point(2.793475881513, 19.29562885002))
        path.addCurve(to: point(7.36, 19.188),
                      control1: point(4.704566919323, 21.206301402943),
                      control2: point(6.363240902818, 20.529118666533))

        path.move(to: point(16.5, 9))
        path.addCurve(to: point(15, 10.5),
                      control1: point(16.5, 9.828427124746),
                      control2: point(15.828427124746, 10.5))
        path.addCurve(to: point(13.5, 9),
                      control1: point(14.171572875254, 10.5),
                      control2: point(13.5, 9.828427124746))
        path.addCurve(to: point(15, 7.5),
                      control1: point(13.5, 8.171572875254),
                      control2: point(14.171572875254, 7.5))
        path.addCurve(to: point(16.5, 9),
                      control1: point(15.828427124746, 7.5),
                      control2: point(16.5, 8.171572875254))
        path.closeSubpath()

        return path
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
