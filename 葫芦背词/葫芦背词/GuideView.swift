import SwiftUI

struct GuideView: View {
    @State private var currentStep: Int = 0
    @State private var offsetY: CGFloat = 0
    private let topPadding: CGFloat = 100
    var onDismiss: () -> Void

    private let guides: [GuideStep] = [
        GuideStep(
            title: "葫芦背书法教程",
            heading: "一页单词如何算会背？",
            description: "",
            bulletPoints: [
                BulletPoint(icon: "👁️", text: "隐藏中文释义"),
                BulletPoint(icon: "✏️", text: "能当场复述出意思")
            ],
            imageName: "guide_screenshot"
        ),
        GuideStep(
            title: "葫芦背书法教程",
            heading: "背熟了看位置就知道意思怎么办？",
            description: "",
            bulletPoints: [
                BulletPoint(icon: "🔀", text: "玻环左滑打乱单词顺序"),
                BulletPoint(icon: "📎", text: "重新串联单词记忆")
            ],
            imageName: "guide_screenshot2"
        ),
        GuideStep(
            title: "葫芦背书法教程",
            heading: "如何导入新的单词进词书？",
            description: "",
            bulletPoints: [
                BulletPoint(icon: "🤖", text: "告诉葫芦AI导入单词的格式"),
                BulletPoint(icon: "⚡️", text: "复制然后粘贴到小闪电⚡️里一键导入")
            ],
            imageName: "guide_screenshot3"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top transparent spacer - creates the gap to see app behind
                Color.clear
                    .frame(height: topPadding + offsetY)

                // Actual Guide content card
                VStack(spacing: 0) {
                    // Header with back button and step indicators
                    HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.black : Color(.systemGray6))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(index == currentStep ? Color.white : Color(.label))
                            }
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                        // Image placeholder or actual image
                        if let imageName = guides[currentStep].imageName {
                            VStack(spacing: 16) {
                                // Image - spans nearly full width
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 380)
                                    .cornerRadius(16)
                                    .padding(24)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(24)
                                    .padding(.horizontal, -16)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Main heading
                        VStack(alignment: .leading, spacing: 8) {
                            Text(guides[currentStep].heading)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(.label))

                            if !guides[currentStep].description.isEmpty {
                                Text(guides[currentStep].description)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                        // Bullet points
                        VStack(spacing: 16) {
                            ForEach(Array(guides[currentStep].bulletPoints.enumerated()), id: \.element) { index, point in
                                HStack(spacing: 12) {
                                    // Use SF Symbols for the first pages and custom icons for the import step
                                    if currentStep == 0 {
                                        if index == 0 {
                                            Image(systemName: "eye.slash")
                                                .font(.system(size: 20))
                                                .frame(width: 24, alignment: .center)
                                                .foregroundStyle(Color(.label))
                                        } else if index == 1 {
                                            Image(systemName: "speaker.wave.2")
                                                .font(.system(size: 20))
                                                .frame(width: 24, alignment: .center)
                                                .foregroundStyle(Color(.label))
                                        }
                                    } else if currentStep == 1 {
                                        if index == 0 {
                                            Image(systemName: "lightbulb")
                                                .font(.system(size: 20))
                                                .frame(width: 24, alignment: .center)
                                                .foregroundStyle(Color(.label))
                                        } else if index == 1 {
                                            GuidePaperclipIconShape()
                                                .stroke(
                                                    Color(.label),
                                                    style: StrokeStyle(
                                                        lineWidth: 1.5,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                                .frame(width: 24, height: 24, alignment: .center)
                                        }
                                    } else if currentStep == 2 {
                                        if index == 0 {
                                            GuideAIFormatIconShape()
                                                .stroke(
                                                    Color(.label),
                                                    style: StrokeStyle(
                                                        lineWidth: 1.5,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                                .frame(width: 24, height: 24, alignment: .center)
                                        } else if index == 1 {
                                            GuideQuickImportIconShape()
                                                .stroke(
                                                    Color(.label),
                                                    style: StrokeStyle(
                                                        lineWidth: 1.5,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                                .frame(width: 24, height: 24, alignment: .center)
                                        } else {
                                            Text(point.icon)
                                                .font(.system(size: 20))
                                                .frame(width: 24, alignment: .center)
                                        }
                                    } else {
                                        Text(point.icon)
                                            .font(.system(size: 20))
                                            .frame(width: 24, alignment: .center)
                                    }

                                    Text(point.text)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundStyle(Color(.label))
                                        .lineLimit(2)

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .layoutPriority(-1)

            // Next button
            Button(action: nextStep) {
                Text(currentStep == 2 ? "完成" : "下一步")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, max(24, geometry.safeAreaInsets.bottom))
            .layoutPriority(1)
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24
                    )
                    .fill(Color(.systemBackground))
                    .ignoresSafeArea(edges: .bottom)
                )
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            offsetY = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            // Dismiss if dragged more than 120pt
                            withAnimation(.easeInOut(duration: 0.3)) {
                                offsetY = geometry.size.height
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    onDismiss()
                                }
                            }
                        } else {
                            // Spring back if not dragged enough
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offsetY = 0
                            }
                        }
                    }
            )
        }
    }

    private func nextStep() {
        if currentStep < 2 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
            Haptic.trigger(.medium)
        } else {
            Haptic.trigger(.medium)
            onDismiss()
        }
    }
}

private struct GuideStep {
    let title: String
    let heading: String
    let description: String
    let bulletPoints: [BulletPoint]
    let imageName: String?
}

private struct BulletPoint: Hashable {
    let icon: String
    let text: String
}

struct GuideView_Previews: PreviewProvider {
    static var previews: some View {
        GuideView(onDismiss: {})
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct EyeSlashIcon: View {
    var body: some View {
        Image(systemName: "eye.slash")
            .font(.system(size: 20))
    }
}

struct SpeakerIcon: View {
    var body: some View {
        Image(systemName: "speaker.wave.2")
            .font(.system(size: 20))
    }
}


private struct GuideAIFormatIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var iconPath = Path()
        iconPath.move(to: CGPoint(x: 6.75, y: 7.5))
        iconPath.addLine(to: CGPoint(x: 9.75, y: 9.75))
        iconPath.addLine(to: CGPoint(x: 6.75, y: 12))
        iconPath.move(to: CGPoint(x: 11.25, y: 12))
        iconPath.addLine(to: CGPoint(x: 14.25, y: 12))

        let container = Path(
            roundedRect: CGRect(x: 3, y: 3.75, width: 18, height: 16.5),
            cornerRadius: 2.25
        )
        iconPath.addPath(container)

        return iconPath.fittingHeroicon(in: rect)
    }
}

private struct GuideQuickImportIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var iconPath = Path()
        iconPath.move(to: CGPoint(x: 3.75, y: 13.5))
        iconPath.addLine(to: CGPoint(x: 14.25, y: 2.25))
        iconPath.addLine(to: CGPoint(x: 12, y: 10.5))
        iconPath.addLine(to: CGPoint(x: 20.25, y: 10.5))
        iconPath.addLine(to: CGPoint(x: 9.75, y: 21.75))
        iconPath.addLine(to: CGPoint(x: 12, y: 13.5))
        iconPath.addLine(to: CGPoint(x: 3.75, y: 13.5))
        iconPath.closeSubpath()

        return iconPath.fittingHeroicon(in: rect)
    }
}

private struct GuidePaperclipIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var iconPath = Path()
        iconPath.move(to: CGPoint(x: 18.375, y: 12.739))
        iconPath.addLine(to: CGPoint(x: 10.682, y: 20.432))
        iconPath.addCurve(
            to: CGPoint(x: 4.318, y: 14.068),
            control1: CGPoint(x: 9.196, y: 21.918),
            control2: CGPoint(x: 5.804, y: 18.526)
        )
        iconPath.addLine(to: CGPoint(x: 15.258, y: 3.128))
        iconPath.addCurve(
            to: CGPoint(x: 19.5, y: 7.372),
            control1: CGPoint(x: 16.407, y: 1.978),
            control2: CGPoint(x: 19.5, y: 5.222)
        )
        iconPath.addLine(to: CGPoint(x: 8.552, y: 18.32))
        iconPath.move(to: CGPoint(x: 8.561, y: 18.31))
        iconPath.addLine(to: CGPoint(x: 8.551, y: 18.32))
        iconPath.move(to: CGPoint(x: 14.25, y: 8.369))
        iconPath.addLine(to: CGPoint(x: 6.44, y: 16.179))
        iconPath.addCurve(
            to: CGPoint(x: 8.552, y: 18.309),
            control1: CGPoint(x: 5.854, y: 16.765),
            control2: CGPoint(x: 6.966, y: 17.877)
        )

        return iconPath.fittingHeroicon(in: rect)
    }
}

private extension Path {
    func fittingHeroicon(in rect: CGRect) -> Path {
        let viewBox: CGFloat = 24
        guard rect.width > 0 && rect.height > 0 else { return self }

        let scale = min(rect.width, rect.height) / viewBox
        let xOffset = rect.minX + (rect.width - viewBox * scale) / 2
        let yOffset = rect.minY + (rect.height - viewBox * scale) / 2

        return self
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .applying(CGAffineTransform(translationX: xOffset, y: yOffset))
    }
}
