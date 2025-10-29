import SwiftUI

struct SignInView: View {
    private enum SignInMethod: CaseIterable, Hashable {
        case password
        case otp

        var label: String {
            switch self {
            case .password:
                return "密码登录"
            case .otp:
                return "验证码登录"
            }
        }
    }

    @EnvironmentObject private var sessionStore: AuthSessionStore
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var otpCode: String = ""
    @State private var signInMethod: SignInMethod = .password
    @State private var isLoading = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("欢迎回来")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("使用 Supabase 账号登录以同步词书数据。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Picker("登录方式", selection: $signInMethod) {
                    ForEach(SignInMethod.allCases, id: \.self) { method in
                        Text(method.label).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 16) {
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                    switch signInMethod {
                    case .password:
                        SecureField("密码", text: $password)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    case .otp:
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("验证码", text: $otpCode)
                                    .textInputAutocapitalization(.never)
                                    .textContentType(.oneTimeCode)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .frame(maxWidth: .infinity)

                                Button {
                                    Task { await sendEmailCode() }
                                } label: {
                                    if isSendingCode {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("发送验证码")
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(width: 120, height: 44)
                                .buttonStyle(.borderedProminent)
                                .tint(Color.accentColor)
                                .disabled(isSendingCode || trimmedEmail.isEmpty)
                            }

                            Text("验证码将发送至上方邮箱，请在 10 分钟内输入。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await attemptSignIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("登录")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 52)
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(isLoading || !isFormValid)

                Spacer()
            }
            .padding(.top, 80)
            .padding(.horizontal, 24)
            .background(Color(.systemBackground))
            .onChange(of: email) { _, _ in clearError(resetSuccess: true) }
            .onChange(of: password) { _, _ in clearError() }
            .onChange(of: otpCode) { _, _ in clearError() }
            .onChange(of: signInMethod) { _, newMethod in
                clearError(resetSuccess: true)
                switch newMethod {
                case .password:
                    otpCode = ""
                case .otp:
                    password = ""
                }
            }
            .navigationTitle("登录")
        }
    }

    private var isFormValid: Bool {
        switch signInMethod {
        case .password:
            return !trimmedEmail.isEmpty && !trimmedPassword.isEmpty
        case .otp:
            return !trimmedEmail.isEmpty && !trimmedOTPCode.isEmpty
        }
    }

    private func attemptSignIn() async {
        guard !isLoading else { return }
        clearError(resetSuccess: true)
        isLoading = true
        defer { isLoading = false }

        do {
            switch signInMethod {
            case .password:
                try await sessionStore.signIn(email: email, password: password)
            case .otp:
                try await sessionStore.signInWithEmailOTP(email: email, code: otpCode)
            }
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

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOTPCode: String {
        otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
