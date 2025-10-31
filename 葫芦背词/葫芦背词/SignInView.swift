import SwiftUI
import UIKit

private let signInPrimaryAccent = Color(red: 0.06, green: 0.40, blue: 0.29)
private let signInSecondaryAccent = Color(red: 0.18, green: 0.42, blue: 0.33)

struct SignInView: View {
    @EnvironmentObject private var sessionStore: AuthSessionStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var email: String
    @State private var otpCode: String = ""
    @State private var rememberAccount: Bool
    @State private var isLoading = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var emailValidationActivated = false
    @State private var resendCountdown: Int = 0
    @State private var countdownTimer: Timer?

    private static let rememberKey = "HuluBeici.Login.remember"
    private static let emailKey = "HuluBeici.Login.email"

    init() {
        let storedRemember = UserDefaults.standard.object(forKey: Self.rememberKey) as? Bool ?? true
        let storedEmailRaw = storedRemember ? (UserDefaults.standard.string(forKey: Self.emailKey) ?? "") : ""
        let sanitizedStoredEmail: String
        if let validated = try? EmailValidator.validate(storedEmailRaw) {
            sanitizedStoredEmail = validated
        } else {
            sanitizedStoredEmail = ""
            UserDefaults.standard.removeObject(forKey: Self.emailKey)
        }
        _rememberAccount = State(initialValue: storedRemember)
        _email = State(initialValue: sanitizedStoredEmail)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
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
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emailValidationActivated = false
                }
            }
            .onChange(of: otpCode) {
                clearError()
            }
            .onChange(of: rememberAccount) { _, newValue in
                updateRememberChoice(newValue)
            }
            .navigationBarHidden(true)
            .onDisappear {
                stopResendCooldown()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nice to")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(headerTitleColor)
            Text("meet you")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(headerTitleColor)
            Text("Welcome to log in")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(headerSubtitleColor)
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

            if let emailHint = emailValidationMessage {
                Text(emailHint)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("验证码")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(formLabelColor)

                OTPInputRow(
                    code: $otpCode,
                    isSending: isSendingCode,
                    canSend: canSendOTPCode,
                    remainingSeconds: resendCountdown,
                    onSend: { Task { await sendEmailCode() } }
                )

                Text("验证码将发送至您的邮箱，请在 10 分钟内输入。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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
                        .fill(primaryButtonBackground)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
        }
        .allowsHitTesting(isButtonEnabled)
        .buttonStyle(.plain)
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(.systemBackground),
                Color(.secondarySystemBackground)
            ]
        }
        return [
            Color(red: 1.0, green: 0.99, blue: 0.94),
            Color(red: 1.0, green: 0.94, blue: 0.97)
        ]
    }

    private var headerTitleColor: Color {
        colorScheme == .dark ? .primary : signInPrimaryAccent
    }

    private var headerSubtitleColor: Color {
        colorScheme == .dark ? .secondary : signInSecondaryAccent
    }

    private var formLabelColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.85) : Color.black.opacity(0.6)
    }

    private var primaryButtonBackground: Color {
        colorScheme == .dark ? signInPrimaryAccent : Color(red: 0.02, green: 0.02, blue: 0.02)
    }

    private var sanitizedEmailValue: String? {
        try? EmailValidator.validate(email)
    }

    private var emailValidationError: EmailValidator.ValidationError? {
        EmailValidator.validationError(for: email)
    }

    private var emailValidationMessage: String? {
        let trimmed = trimmedEmail
        guard !trimmed.isEmpty else { return nil }
        let shouldShowHint = emailValidationActivated || trimmed.contains("@")
        guard shouldShowHint else { return nil }
        guard let error = emailValidationError, error != .empty else { return nil }
        return error.errorDescription
    }

    private var isCooldownActive: Bool {
        resendCountdown > 0
    }

    private var canSendOTPCode: Bool {
        sanitizedEmailValue != nil && !isSendingCode && !isCooldownActive
    }

    private var isFormValid: Bool {
        sanitizedEmailValue != nil && !trimmedOTPCode.isEmpty
    }

    private func attemptSignIn() async {
        guard !isLoading else { return }
        emailValidationActivated = true
        guard let sanitizedEmail = sanitizedEmailValue else {
            errorMessage = emailValidationError?.errorDescription ?? "请输入有效的邮箱地址。"
            successMessage = nil
            return
        }
        clearError(resetSuccess: true)
        isLoading = true
        defer { isLoading = false }

        do {
            try await sessionStore.signInWithEmailOTP(email: sanitizedEmail, code: otpCode)
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
        guard !isCooldownActive else { return }
        emailValidationActivated = true
        guard let sanitizedEmail = sanitizedEmailValue else {
            errorMessage = emailValidationError?.errorDescription ?? "请输入有效的邮箱地址。"
            successMessage = nil
            return
        }

        isSendingCode = true
        defer { isSendingCode = false }

        do {
            try await sessionStore.requestEmailOTP(email: sanitizedEmail)
            successMessage = "验证码已发送至邮箱，请查收。"
            errorMessage = nil
            startResendCooldown()
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
        if let sanitized = try? EmailValidator.validate(value) {
            UserDefaults.standard.set(sanitized, forKey: Self.emailKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.emailKey)
        }
    }

    private func updateRememberChoice(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.rememberKey)
        if value {
            if let sanitized = sanitizedEmailValue {
                UserDefaults.standard.set(sanitized, forKey: Self.emailKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.emailKey)
            }
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

    private func startResendCooldown(_ seconds: Int = 60) {
        stopResendCooldown()
        guard seconds > 0 else { return }
        resendCountdown = seconds
        let timer = Timer(timeInterval: 1, repeats: true) { timer in
            if self.resendCountdown <= 1 {
                timer.invalidate()
                self.countdownTimer = nil
                self.resendCountdown = 0
            } else {
                self.resendCountdown -= 1
            }
        }
        timer.tolerance = 0.2
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopResendCooldown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        resendCountdown = 0
    }
}

private struct LabeledInputField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(labelColor)

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
                    .fill(fieldBackgroundColor)
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

    private var labelColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.85) : Color.black.opacity(0.6)
    }

    private var fieldBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(.secondarySystemBackground)
        }
        return Color(red: 0.93, green: 0.99, blue: 0.94).opacity(0.85)
    }
}

private struct OTPInputRow: View {
    @Binding var code: String
    let isSending: Bool
    let canSend: Bool
    let remainingSeconds: Int
    let onSend: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
                        .fill(inputFieldBackgroundColor)
                )

            Button {
                guard canSend else { return }
                onSend()
            } label: {
                let state = buttonState
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(sendButtonBackgroundColor.opacity(state.opacity))
                        .frame(width: 112, height: 44)

                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(signInPrimaryAccent)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(state.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(sendButtonForegroundColor.opacity(state.opacity))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: isSending)
        }
    }

    private var inputFieldBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(.secondarySystemBackground)
        }
        return Color(red: 0.93, green: 0.99, blue: 0.94).opacity(0.85)
    }

    private var sendButtonBackgroundColor: Color {
        if colorScheme == .dark {
            return signInPrimaryAccent.opacity(0.6)
        }
        return Color(red: 0.78, green: 0.95, blue: 0.84).opacity(0.75)
    }

    private var sendButtonForegroundColor: Color {
        colorScheme == .dark ? Color.white : signInPrimaryAccent
    }

    private var buttonState: (title: String, opacity: Double) {
        let isCooldown = remainingSeconds > 0
        let visualOpacity: Double
        if canSend || isSending {
            visualOpacity = 1
        } else if isCooldown {
            visualOpacity = 0.65
        } else {
            visualOpacity = 0.4
        }
        let title = isCooldown ? "重新发送(\(remainingSeconds)s)" : "发送验证码"
        return (title, visualOpacity)
    }
}

private struct RememberRow: View {
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(checkboxBorderColor, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(checkboxFillColor)
                            )
                            .frame(width: 18, height: 18)

                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(signInPrimaryAccent)
                        }
                    }

                    Text("记住邮箱")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(rememberTextColor)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var checkboxBorderColor: Color {
        colorScheme == .dark ? Color(.separator) : Color.black.opacity(0.3)
    }

    private var checkboxFillColor: Color {
        if colorScheme == .dark {
            return isOn ? signInPrimaryAccent.opacity(0.25) : Color(.systemBackground)
        }
        return isOn ? Color(red: 0.69, green: 0.95, blue: 0.78) : Color.white
    }

    private var rememberTextColor: Color {
        colorScheme == .dark ? Color.primary : Color.black.opacity(0.7)
    }
}
