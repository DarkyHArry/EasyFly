import SwiftUI

/// Representa a tela de login do aplicativo.
struct LoginView: View {
    var didLogin: () -> Void
    @State private var email: String = ""
    @State private var password: String = ""

    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedEmail") private var loggedEmail: String = ""

    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingForgotSheet: Bool = false
    @State private var showBiometricSetupAlert: Bool = false
    @State private var pendingEmail: String = ""
    @State private var pendingPassword: String = ""

    @Environment(\.colorScheme) var colorScheme

    // Determina a cor principal do aplicativo (laranja/amarelo)
    private var primaryColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16) // Um amarelo/laranja forte
    }

    // Determina a cor do ícone do avião e do texto "Forgot password?" no modo claro
    private var iconColor: Color {
        // Nas imagens, o ícone é azul no modo claro e laranja no escuro
        // Usamos uma cor adaptativa para a consistência do app no modo claro
        // Vamos usar a cor principal para o modo escuro e um azul para o claro, mas
        // para simplificar e manter a identidade, usaremos a cor principal para o avião aqui.
        primaryColor
    }

    private var forgotPasswordColor: Color {
        colorScheme == .light ? Color.black : iconColor
    }

    @State private var forcedColorScheme: ColorScheme? = nil

    var body: some View {
        ZStack {
            VStack {
                // MARK: - Theme Toggle Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if forcedColorScheme == .dark {
                                forcedColorScheme = .light
                            } else if forcedColorScheme == .light {
                                forcedColorScheme = nil // system default
                            } else {
                                forcedColorScheme = .dark
                            }
                        }
                    }) {
                        let icon = forcedColorScheme == .dark ? "sun.max.fill" : "moon.fill"
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(primaryColor)
                    }
                    .padding(.trailing)
                    .padding(.top, 10)
                }

                Spacer()

                VStack {

            // MARK: - Logo e Título
            
            // Ícone do Avião
            Image(systemName: "airplane")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(iconColor)
                .padding(.bottom, 10)

            // Título do Aplicativo (ex: EasyFly)
            Text("EasyFly")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
                .foregroundColor(.primary)

            // MARK: - Campos de Entrada

            // Campo de Email
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "envelope")
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: email) { new in
                            // Normaliza email enquanto o usuário digita (tudo em minúsculas)
                            let lower = new.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if lower != new { email = lower }
                        }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 15)

            // Campo de Senha
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "lock")
                    SecureField("Password", text: $password)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Biometric login button (se disponível e habilitado)
                let bioType = BiometricManager.shared.getBiometricType()
                if bioType != .none {
                    HStack {
                        Spacer()
                        Button(action: {
                            handleBiometricLogin()
                        }) {
                            let icon = bioType == .faceID ? "faceid" : "touchid"
                            Label("Use \(bioType.description)", systemImage: icon)
                                .font(.subheadline)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)

            // MARK: - Link Esqueceu Senha

            HStack {
                Spacer()
                Button("Forgot password?") {
                    showingForgotSheet = true
                }
                .foregroundColor(forgotPasswordColor)
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // MARK: - Botão de Login
            Button(action: {
                handleLogin()
            }) {
                Text("Log In")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryColor)
                    .cornerRadius(15)
                    .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal)
            .padding(.top, 30)

            Spacer()
            Spacer()
                }
            }
            .padding(.vertical)
            .frame(maxWidth: 600)
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        }
        .preferredColorScheme(forcedColorScheme)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Habilitar Login Biométrico?", isPresented: $showBiometricSetupAlert) {
            Button("Sim, deletar senha") {
                setupBiometricLogin()
            }
            Button("Não, manter senha") {
                didLogin()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            let bioType = BiometricManager.shared.getBiometricType()
            Text("Deseja usar \(bioType.description) para acessar a conta? A senha será removida e você entrará usando apenas biometria.")
        }
        .sheet(isPresented: $showingForgotSheet) {
            ForgotPasswordView(isPresented: $showingForgotSheet)
        }

    }

    // MARK: - Actions
    private func handleLogin() {
        let trimmedEmail = UserManager.shared.normalizeEmail(email)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            alertMessage = "Por favor preencha email e senha."
            showAlert = true
            return
        }

        // Validação de email com cache para performance
        let isValidEmail: Bool
        if let cached = CacheManager.shared.cachedEmailValidation(trimmedEmail) {
            isValidEmail = cached
        } else {
            isValidEmail = Validator.isValidEmail(trimmedEmail)
            CacheManager.shared.cacheEmailValidation(trimmedEmail, isValid: isValidEmail)
        }
        
        guard isValidEmail else {
            alertMessage = "Email inválido. Use um formato como usuario@dominio.com"
            showAlert = true
            return
        }

        if UserManager.shared.hasAccount(email: trimmedEmail) {
            // Usuário existe — verificar senha e lockout
            if UserManager.shared.isLocked(email: trimmedEmail) {
                let minutesLeft = UserManager.shared.getMinutesUntilUnlock(email: trimmedEmail)
                alertMessage = "Conta temporariamente bloqueada. Tente novamente em \(minutesLeft) minuto(s)."
                showAlert = true
                return
            }
            let ok = UserManager.shared.verifyPassword(email: trimmedEmail, password: password)
            if ok {
                loggedEmail = trimmedEmail
                isLoggedIn = true
                // Usar cached biometric type para performance
                let bioType = CacheManager.shared.cachedBiometricType()
                if bioType != .none && !BiometricManager.shared.isBiometricLoginEnabled(for: trimmedEmail) {
                    pendingEmail = trimmedEmail
                    pendingPassword = password
                    showBiometricSetupAlert = true
                } else {
                    didLogin()
                }
            } else {
                alertMessage = "Senha incorreta. Tente novamente ou use 'Forgot password?'."
                showAlert = true
            }
        } else {
            // Novo usuário — validar força da senha e criar
            let issues = Validator.passwordStrengthIssues(password)
            if !issues.isEmpty {
                alertMessage = "Senha inválida: " + issues.joined(separator: ", ")
                showAlert = true
                return
            }
            
            // Validar se a senha não é usada por outro usuário
            if UserManager.shared.isPasswordUsedByOtherUser(password: password, excludeEmail: trimmedEmail) {
                alertMessage = "Senha inválida. Esta senha já está em uso por outro usuário. Escolha uma senha única."
                showAlert = true
                return
            }
            
            let saved = UserManager.shared.createUser(email: trimmedEmail, password: password)
            if saved {
                loggedEmail = trimmedEmail
                isLoggedIn = true
                alertMessage = "Conta criado com sucesso e logado."
                showAlert = true
                // Oferecer biometria para nova conta
                let bioType = CacheManager.shared.cachedBiometricType()
                if bioType != .none {
                    pendingEmail = trimmedEmail
                    pendingPassword = password
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showBiometricSetupAlert = true
                    }
                } else {
                    didLogin()
                }
            } else {
                alertMessage = "Email já existe ou falha ao salvar credenciais."
                showAlert = true
            }
        }
    }

    private func handleBiometricLogin() {
        let normalized = UserManager.shared.normalizeEmail(email)
        guard !normalized.isEmpty else {
            alertMessage = "Por favor insira seu email."
            showAlert = true
            return
        }

        guard BiometricManager.shared.isBiometricLoginEnabled(for: normalized) else {
            alertMessage = "Biometria não configurada para este email. Configure na primeira tentativa de login."
            showAlert = true
            return
        }

        Task {
            let success = await BiometricManager.shared.authenticateWithBiometrics(for: normalized, reason: "Autenticar para entrar na sua conta")
            if success {
                loggedEmail = normalized
                isLoggedIn = true
                didLogin()
            } else {
                alertMessage = "Autenticação biométrica falhou ou foi cancelada."
                showAlert = true
            }
        }
    }

    private func setupBiometricLogin() {
        let success = BiometricManager.shared.setupBiometricLogin(for: pendingEmail)
        if success {
            // Deletar senha do Keychain após setup de biometria
            UserManager.shared.resetFailedAttempts(email: pendingEmail)
            KeychainHelper.shared.deletePassword(account: pendingEmail)
            alertMessage = "Biometria configurada! Agora use apenas \(BiometricManager.shared.getBiometricType().description)."
            showAlert = true
            didLogin()
        } else {
            alertMessage = "Falha ao configurar biometria. Use sua senha normalmente."
            showAlert = true
            didLogin()
        }
    }

}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    var password: String

    private var score: Int { Validator.strengthScore(password) }
    private var label: String { Validator.strengthLabelAndColorKey(password).label }

    private func barColor(for index: Int) -> Color {
        if password.isEmpty { return Color(.systemGray4) }
        if score <= 1 {
            return index < score ? Color.red : Color(.systemGray4)
        } else if score == 2 {
            return index < score ? Color.orange : Color(.systemGray4)
        } else {
            return index < score ? Color.green : Color(.systemGray4)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: i))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
            if !password.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(score <= 1 ? Color.red : (score == 2 ? Color.orange : Color.green))
            }
        }
        .padding(.top, 6)
    }
}

// NOTE: handleLogin moved inside LoginView; duplicated/out-of-scope definitions removed earlier.

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var newPassword: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Email")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: email) { new in
                            let lower = new.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if lower != new { email = lower }
                        }
                }
                Section(header: Text("Nova Senha")) {
                    SecureField("Nova senha", text: $newPassword)
                    PasswordStrengthView(password: newPassword)
                }
            }
            .navigationTitle("Forgot Password")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("sucesso") { isPresented = false }
                })
            }
        }
    }

    private func handleSave() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !newPassword.isEmpty else {
            alertMessage = "Preencha email e nova senha."
            showAlert = true
            return
        }
        // Validação de email
        guard Validator.isValidEmail(trimmed) else {
            alertMessage = "Email inválido."
            showAlert = true
            return
        }

        // Check if account is locked due to failed attempts
        if UserManager.shared.isLocked(email: trimmed) {
            let minutes = UserManager.shared.getMinutesUntilUnlock(email: trimmed)
            alertMessage = "Conta bloqueada. Tente novamente em \(minutes) minuto(s)."
            showAlert = true
            return
        }

        // Validação de senha
        let issues = Validator.passwordStrengthIssues(newPassword)
        if !issues.isEmpty {
            alertMessage = "Senha inválida: " + issues.joined(separator: ", ")
            showAlert = true
            return
        }

        // Atualiza ou cria conta via UserManager
        let saved = UserManager.shared.changePassword(email: trimmed, newPassword: newPassword)
        if saved {
            alertMessage = "Senha atualizada com sucesso."
            UserManager.shared.resetFailedAttempts(email: trimmed)
        } else {
            alertMessage = "Falha ao salvar credenciais."
            UserManager.shared.recordFailedAttempt(email: trimmed)
        }
        showAlert = true
    }
}

struct LoginView_Previews: PreviewProvider {
    static let mockLogin: () -> Void = {}
    static var previews: some View {
        Group {
            LoginView(didLogin: mockLogin)
                .environment(\.colorScheme, .light)
                .previewDisplayName("Modo Claro")

            LoginView(didLogin: mockLogin)
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Modo Escuro")
        }
    }
}
