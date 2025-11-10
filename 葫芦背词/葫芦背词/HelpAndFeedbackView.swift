import SwiftUI

struct HelpAndFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCopyConfirmation = false
    @State private var copiedItem = ""

    private let email = "vbin210327@gmail.com"
    private let xiaohongshu = "Realfan06"

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                VStack(spacing: 24) {
                    Spacer()

                    // Title
                    Text("帮助与反馈")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)

                    // Description
                    VStack(spacing: 8) {
                        Text("如需帮助，可联系小红书：")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)

                        Text(xiaohongshu)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)

                        Text("或邮件：\(email)")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)

                    Spacer()

                    // Copy buttons
                    VStack(spacing: 0) {
                        Button(action: {
                            UIPasteboard.general.string = xiaohongshu
                            Haptic.trigger(.medium)
                            copiedItem = "小红书号"
                            showCopyConfirmation = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopyConfirmation = false
                            }
                        }) {
                            Text("复制小红书号")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }

                        Divider()
                            .background(Color(.separator))

                        Button(action: {
                            UIPasteboard.general.string = email
                            Haptic.trigger(.medium)
                            copiedItem = "邮箱"
                            showCopyConfirmation = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopyConfirmation = false
                            }
                        }) {
                            Text("复制邮箱")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }

                        Divider()
                            .background(Color(.separator))

                        Button(action: {
                            Haptic.trigger(.light)
                            dismiss()
                        }) {
                            Text("确定")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .padding(.top, 60)
            }

            // Copy confirmation toast
            if showCopyConfirmation {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已复制\(copiedItem)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopyConfirmation)
            }
        }
    }
}
