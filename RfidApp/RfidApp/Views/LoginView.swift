import SwiftUI

struct LoginView: View {
    @ObservedObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var savePassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo & branding
                VStack(spacing: AppTheme.Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                            .fill(AppTheme.primary.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .padding(.top, AppTheme.Spacing.xxl)

                    Text("DMTN RFID")
                        .font(.system(size: AppTheme.FontSize.largeTitle, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Gestão de estoque e leitura RFID")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.bottom, AppTheme.Spacing.xl)

                // Form card
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    if let msg = errorMessage {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text(msg)
                                .font(.system(size: AppTheme.FontSize.caption, weight: .medium))
                                .foregroundStyle(AppTheme.error)
                        }
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("E-mail")
                            .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("seu@email.com", text: $email)
                            .textFieldStyle(.plain)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .disabled(isLoading)
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Senha")
                            .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Group {
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                } else {
                                    SecureField("••••••••", text: $password)
                                        .textContentType(.password)
                                }
                            }
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .password)
                            .disabled(isLoading)
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .disabled(isLoading)
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }

                    Toggle(isOn: $savePassword) {
                        Text("Salvar senha")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .tint(AppTheme.primary)

                    Button {
                        focusedField = nil
                        Task { await doLogin() }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Entrar")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .shadow(color: AppTheme.shadow, radius: 16, x: 0, y: 4)
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .onAppear { loadSavedCredentials() }
    }

    private func loadSavedCredentials() {
        savePassword = auth.shouldSavePassword
        if savePassword, let saved = auth.savedEmail {
            email = saved
            if let pwd = auth.savedPassword { password = pwd }
        }
    }

    private func doLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.login(email: email, password: password)
            auth.shouldSavePassword = savePassword
            if savePassword {
                auth.saveCredentials(email: email, password: password)
            } else {
                auth.clearSavedCredentials()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
