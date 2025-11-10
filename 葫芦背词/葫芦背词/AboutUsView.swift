import SwiftUI

struct AboutUsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 40)

                        // Title
                        Text("关于我们")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)

                        // Main content
                        VStack(alignment: .leading, spacing: 16) {
                            Text("葫芦背词是一款打破传统背词方法的产品，无数人在学生时期曾被记单词所困扰，大家都知道词汇是英语的基础，一门语言的基础，但是却\"无从下手\"，看着陌生的单词感到望而却步，多少人因此放弃了学习英语，放弃了这门语言，潜意识里认为自己无法掌握它，这太难了！")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .lineSpacing(6)

                            Text("是的，曾经的我也是这样想的，直到我发现了葫芦背词法，它没有复杂的3、7、14、21、28天复习记忆曲线，没有看着单词盲猜意思点击卡片的反人类设计，我们依靠大量快速的重复来达到长期记忆，科学理论也证明\"重复是记忆的本质\"，在保证记忆质量的同时快速提高你的记忆效率，并且启动阻力低，任何时间任何地方都可以随时开始背词，这是一个投入20%精力就能收获80%效果的方法。")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .lineSpacing(6)

                            Text("我就是活生生的例子，利用这个方法，从高三英语30多分，答题全靠蒙，短短3个月时间到最后高考100+的分数，如果你在应试阶段，我们几乎可以保证利用这个方法，再搭配上一些阅读训练，你的英语分数是100分起步，不管你的基础有多差。")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .lineSpacing(6)

                            VStack(spacing: 8) {
                                Text("我们的使命是：")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("\"从破解单词开始，让你入门英语，取得高分，爱上英语\"")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                                    .italic()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.leading)

                        Spacer()
                            .frame(height: 40)
                    }
                }

                // Bottom button
                Button(action: {
                    Haptic.trigger(.light)
                    dismiss()
                }) {
                    Text("知道了")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Rectangle()
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5),
                            alignment: .top
                        )
                }
            }
        }
    }
}
