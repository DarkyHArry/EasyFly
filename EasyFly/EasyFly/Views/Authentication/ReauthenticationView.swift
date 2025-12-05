import SwiftUI
import LocalAuthentication
import os

/// Tela de re-autenticação que aparece quando o app volta do background.
struct ReauthenticationView: View {
    @EnvironmentObject var lifecycleManager: AppLifecycleManager
    @State private var isAuthenticating = false
    @State private var authError: String = ""
    @State private var showError = false
    @Environment(\.colorScheme) var colorScheme
    
    var loggedEmail: String = ""
    var onSuccess: () -> Void = {}
    
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "Reauth")
    private var primaryColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16) // Amarelo/laranja principal
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Ícone de segurança
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(primaryColor)
                
                // Título
                Text("Verificação de Segurança")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Mensagem
                Text("Seu aplicativo detectou um tempo de inatividade. Por segurança, autentique-se novamente.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Email logado
                if !loggedEmail.isEmpty {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(primaryColor)
                        Text(loggedEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Botão de autenticação biométrica
                let bioType = BiometricManager.shared.getBiometricType()
                if bioType != .none && BiometricManager.shared.isBiometricLoginEnabled(for: loggedEmail) {
                    Button(action: {
                        authenticateWithBiometric()
                    }) {
                        HStack {
                            let icon = bioType == .faceID ? "faceid" : "touchid"
                            Image(systemName: icon)
                            Text("Autenticar com \(bioType.description)")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal)
                }
                
                // Botão de logout (alternativa)
                Button(action: {
                    logout()
                }) {
                    Text("Fazer Logout")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
        }
        .alert("Erro de Autenticação", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(authError)
        }
    }
    
    private func authenticateWithBiometric() {
        isAuthenticating = true
        
        Task {
            let success = await BiometricManager.shared.authenticateWithBiometrics(
                for: loggedEmail,
                reason: "Verificação de segurança - autentique para continuar"
            )
            
            DispatchQueue.main.async {
                isAuthenticating = false
                
                if success {
                    os_log("Re-authentication successful for %{private}@", log: logger, type: .info, loggedEmail)
                    lifecycleManager.resetReauthRequirement()
                    onSuccess()
                } else {
                    authError = "Falha na autenticação. Tente novamente."
                    showError = true
                    os_log("Re-authentication failed for %{private}@", log: logger, type: .default, loggedEmail)
                }
            }
        }
    }
    
    private func logout() {
        os_log("User logout from re-authentication screen for %{private}@", log: logger, type: .default, loggedEmail)
        BiometricManager.shared.clearBiometricData(for: loggedEmail)
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "loggedEmail")
        lifecycleManager.resetReauthRequirement()
        onSuccess()
    }
}

#Preview {
    ReauthenticationView(loggedEmail: "user@example.com")
        .environmentObject(AppLifecycleManager.shared)
}
