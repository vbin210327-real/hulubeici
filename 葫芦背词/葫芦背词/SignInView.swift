import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject private var sessionStore: AuthSessionStore

    @State private var email: String
    @State private var otpCode: String = ""
    @State private var rememberAccount: Bool
    @State private var isLoading = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private static let rememberKey = "HuluBeici.Login.remember"
    private static let emailKey = "HuluBeici.Login.email"

    init() {
        let storedRemember = UserDefaults.standard.object(forKey: Self.rememberKey) as? Bool ?? true
        let storedEmail = storedRemember ? (UserDefaults.standard.string(forKey: Self.emailKey) ?? "") : ""
        _rememberAccount = State(initialValue: storedRemember)
        _email = State(initialValue: storedEmail)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.99, blue: 0.94),
                        Color(red: 1.0, green: 0.94, blue: 0.97)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    header

                    formFields

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.1, green: 0.55, blue: 0.32))
                    }

                    signInButton

                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
            }
            .onChange(of: email) { _, newValue in
                clearError(resetSuccess: true)
                persistEmailIfNeeded(newValue)
            }
            .onChange(of: otpCode) {
                clearError()
            }
            .onChange(of: rememberAccount) { _, newValue in
                updateRememberChoice(newValue)
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nice to")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(Color(red: 0.06, green: 0.40, blue: 0.29))
            Text("meet you")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(Color(red: 0.06, green: 0.40, blue: 0.29))
            Text("Welcome to log in")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.18, green: 0.42, blue: 0.33))
                .padding(.top, 4)
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            LabeledInputField(
                label: "邮箱",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("验证码")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))

                OTPInputRow(
                    code: $otpCode,
                    isSending: isSendingCode,
                    canSend: !trimmedEmail.isEmpty && !isSendingCode,
                    onSend: { Task { await sendEmailCode() } }
                )

                Text("验证码将发送至您的邮箱，请在 10 分钟内输入。")
                    .font(.system(size: 12))
                    .foregroundColor(Color.black.opacity(0.45))
            }

            RememberRow(isOn: $rememberAccount)
        }
    }

    private var signInButton: some View {
        let isButtonEnabled = !isLoading && isFormValid

        return Button {
            guard isButtonEnabled else { return }
            Task { await attemptSignIn() }
        } label: {
            Text(isLoading ? "登录中…" : "登录")
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(Color.white.opacity(0.95))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.02, green: 0.02, blue: 0.02))
                )
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
        }
        .allowsHitTesting(isButtonEnabled)
        .buttonStyle(.plain)
    }

    private var isFormValid: Bool {
        !trimmedEmail.isEmpty && !trimmedOTPCode.isEmpty
    }

    private func attemptSignIn() async {
        guard !isLoading else { return }
        clearError(resetSuccess: true)
        isLoading = true
        defer { isLoading = false }

        do {
            try await sessionStore.signInWithEmailOTP(email: email, code: otpCode)
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = "登录失败，请稍后再试。"
            }
        }
    }

    private func sendEmailCode() async {
        guard !isSendingCode else { return }
        let sanitizedEmail = trimmedEmail
        guard !sanitizedEmail.isEmpty else {
            errorMessage = "请输入邮箱地址。"
            successMessage = nil
            return
        }

        isSendingCode = true
        defer { isSendingCode = false }

        do {
            try await sessionStore.requestEmailOTP(email: sanitizedEmail)
            successMessage = "验证码已发送至邮箱，请查收。"
            errorMessage = nil
        } catch {
            successMessage = nil
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = "发送验证码失败，请稍后再试。"
            }
        }
    }

    private func clearError(resetSuccess: Bool = false) {
        errorMessage = nil
        if resetSuccess {
            successMessage = nil
        }
    }

    private func persistEmailIfNeeded(_ value: String) {
        guard rememberAccount else { return }
        UserDefaults.standard.set(value, forKey: Self.emailKey)
    }

    private func updateRememberChoice(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.rememberKey)
        if value {
            UserDefaults.standard.set(email, forKey: Self.emailKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.emailKey)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOTPCode: String {
        otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LabeledInputField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.6))

            field
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField(label, text: $text)
            .font(.system(size: 16, weight: .medium))
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.99, blue: 0.94).opacity(0.75))
            )
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

        if let textContentType {
            base.textContentType(textContentType)
        } else {
            base
        }
    }
}

private struct OTPInputRow: View {
    @Binding var code: String
    let isSending: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("验证码", text: $code)
                .font(.system(size: 16, weight: .medium))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.99, blue: 0.94).opacity(0.75))
                )

            Button {
                guard canSend else { return }
                onSend()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.78, green: 0.95, blue: 0.84).opacity(0.75))
                        .frame(width: 112, height: 44)

                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(red: 0.06, green: 0.40, blue: 0.29))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("发送验证码")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.06, green: 0.40, blue: 0.29))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: isSending)
        }
    }
}

private struct RememberRow: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isOn ? Color(red: 0.69, green: 0.95, blue: 0.78) : Color.white)
                            )
                            .frame(width: 18, height: 18)

                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.06, green: 0.40, blue: 0.29))
                        }
                    }

                    Text("记住邮箱")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
