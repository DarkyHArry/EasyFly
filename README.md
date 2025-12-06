# EasyFly — iOS Flight Booking App

**Versão**: 2.0 - Alpha Test include BUGS!  
**Status**: Production-Ready (Phases 3-6 roadmap included)  
**Última Atualização**: Novembro 2025

---

## 📋 Sobre o Projeto

EasyFly é um aplicativo iOS seguro de reserva de voos com:

✅ **Autenticação Robusta**
- Email + Password com SHA-256 hashing
- Biometria (TouchID/FaceID) com encriptação AES-256-GCM
- Rate limiting (5 tentativas → 5 min lockout)
- Re-autenticação ao retornar do background (30s)
- Validação de senha duplicada (previne reutilização entre usuários)
# EasyFly — Fases 3-6: Plano de Conclusão e App Store

**Versão**: 2.0 Final (Phase 2 Complete + Phases 3-6 Roadmap)  
**Data**: Novembro 2025  
**Status**: Phase 2 ✅ Completo | Phases 3-6 🚀 Roadmap

---

## 📋 Resumo Executivo

O EasyFly completou a **Phase 2 (Security Hardening)** com sucesso:
- ✅ 7 vulnerabilidades críticas corrigidas
- ✅ 200+ linhas de código de segurança adicionadas
- ✅ SHA-256 password hashing implementado
- ✅ PBKDF2 per-user encryption para biometria
- ✅ Rate limiting em todos endpoints de autenticação
- ✅ Re-autenticação biométrica ao retornar do background
- ✅ Validação robusta de emails (RFC 5321)

**Próxima meta**: App Store submission Q1 2026 com Phases 3-6 completas.

---

## 🚀 Phase 3: Backend API Integration (4 semanas)

**Objetivo**: Integrar servidor backend seguro para autenticação baseada em tokens.

### Tarefas

#### 3.1 Design da API RESTful
- **Endpoint**: POST `/api/v1/auth/register` (crear usuario)
- **Endpoint**: POST `/api/v1/auth/login` (login + refresh token)
- **Endpoint**: POST `/api/v1/auth/refresh` (renovar token expirado)
- **Endpoint**: POST `/api/v1/auth/logout` (invalidar tokens)
- **Endpoint**: POST `/api/v1/auth/reset-password` (reset de senha)
- **Segurança**: HTTPS only, certificate pinning, rate limiting (50 req/min por IP)

**Arquivo**: `APIClient.swift` (novo)
```swift
struct AuthAPI {
    func register(email: String, passwordHash: String) async throws -> AuthResponse
    func login(email: String, passwordHash: String) async throws -> TokenResponse
    func refreshToken(refreshToken: String) async throws -> TokenResponse
    func logout(accessToken: String) async throws -> Void
    func resetPassword(email: String, newPasswordHash: String) async throws -> Void
}
```

#### 3.2 Token Management
- **Token Type**: JWT (JSON Web Token) com HS256
- **Access Token**: TTL = 1 hora
- **Refresh Token**: TTL = 30 dias
- **Storage**: Ambos armazenados em Keychain com encriptação
- **Rotation**: Refresh token renovado a cada 7 dias automaticamente

**Arquivo**: `TokenManager.swift` (novo)
```swift
struct TokenManager {
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws
    func getAccessToken() -> String?
    func refreshAccessToken() async throws -> String
    func clearTokens() throws
    func isTokenExpired(_ token: String) -> Bool
}
```

#### 3.3 HTTPS Certificate Pinning
- **Framework**: URLSessionConfiguration + URLSessionDelegate
- **Certificados**: Pinnar 2-3 certificados CA principais + backup
- **Fallback**: Se pinning falhar, log error + mostrar mensagem de segurança
- **Rotação**: Implementar mecanismo de atualização de certs (in-app ou OTA)

**Arquivo**: `NetworkSecurity.swift` (novo)
```swift
class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    // Validar certificado contra lista de certificados públicos conhecidos
}
```

#### 3.4 Integração LoginView → Backend
- Substituir `UserManager.createUser()` por `AuthAPI.register()`
- Substituir `UserManager.verifyPassword()` por `AuthAPI.login()`
- Armazenar tokens em Keychain via `TokenManager`
- Usar access token em headers: `Authorization: Bearer <token>`
- Implementar token refresh automático (interceptor)

#### 3.5 Testes
- Unit tests para TokenManager (expiração, refresh)
- Integration tests para AuthAPI (mock server)
- Network tests para certificate pinning
- Cobertura: 80%+ do código de autenticação

**Timeline**: Semanas 1-4
**Owner**: Backend Team (API) + iOS Team (Client)

---

## 🔐 Phase 4: Advanced Security Features (3 semanas)

**Objetivo**: Implementar recursos avançados de segurança para proteger contra ataques sofisticados.

### Tarefas

#### 4.1 Two-Factor Authentication (2FA)
- **Tipo**: TOTP (Time-based One-Time Password) como opção principal
- **Fallback**: SMS OTP para usuários sem autenticador
- **Fluxo**:
  1. Login com email + password ✅
  2. Servidor envia TOTP challenge
  3. Usuário insere código do Google Authenticator (ou similar)
  4. Servidor valida TOTP + emite tokens

**Arquivo**: `TwoFactorView.swift` (novo)
```swift
struct TwoFactorView: View {
    @State var totpCode: String = ""
    func handleTwoFactorSubmit()
}
```

#### 4.2 Jailbreak/Root Detection
- **Objetivo**: Detectar se device foi "hackeado" e alertar usuário
- **Métodos**:
  - Verificar presença de arquivos conhecidos de jailbreak (`/var/mobile/Library/Caches`, etc.)
  - Detectar Frida/Cydia instalados
  - Verificar se app foi assinado corretamente
  - Checar permissões anormais (sandbox escape)
- **Ação**: Se jailbreak detectado, mostrar alerta e desabilitar biometria

**Arquivo**: `SecurityChecker.swift` (novo)
```swift
struct JailbreakDetector {
    static func isDeviceJailbroken() -> Bool
    static func checkCodeSigning() -> Bool
    static func checkSandbox() -> Bool
}
```

#### 4.3 Anomaly Detection
- **Objetivo**: Detectar padrões suspeitos de login
- **Sinais**:
  - Login de geolocalização impossível (ex: São Paulo → Los Angeles em 1 hora)
  - Login de dispositivo novo sem confirmação
  - 10+ login attempts em 10 minutos
  - Login fora de horário normal do usuário
- **Ação**: Pedir re-autenticação biométrica extra ou 2FA

**Arquivo**: `AnomalyDetector.swift` (novo)
```swift
struct AnomalyDetector {
    static func checkLoginAnomaly(location: CLLocation, device: String) -> Bool
    static func isImpossibleTravel(lastLocation: CLLocation, currentLocation: CLLocation, timeDiff: TimeInterval) -> Bool
}
```

#### 4.4 Secure Logout
- **Local**: Limpar todos os tokens do Keychain
- **Remote**: Chamar `/api/v1/auth/logout` para invalidar sessão no servidor
- **Session**: Deletar cookies/local storage
- **Biometria**: Limpar dados biométricos
- **Cache**: Limpar cache de email validation

**Arquivo**: Atualizar `UserManager.logout()` + ProfileView

#### 4.5 Session Management
- **Timeout**: 12 horas de inatividade → logout automático
- **Multiple Devices**: Limpar tokens de outros devices ao fazer logout
- **Concurrent Sessions**: Máximo 3 sessões simultâneas por usuário

**Arquivo**: `SessionManager.swift` (novo)

#### 4.6 Testes
- Unit tests para JailbreakDetector
- Integration tests para 2FA flow
- Security tests para anomaly detection

**Timeline**: Semanas 5-7
**Owner**: Security Team + iOS Team

---

## 📊 Phase 5: Analytics, Monitoring & Optimization (2 semanas)

**Objetivo**: Coletar metrics, monitorar saúde da app, e otimizar performance.

### Tarefas

#### 5.1 Analytics Framework
- **Ferramenta**: Firebase Analytics (Google) ou Amplitude
- **Eventos para rastrear**:
  - `app_launch` (com versão + device model)
  - `login_success` / `login_failure` (sem PII)
  - `password_reset` (sucesso/falha)
  - `biometric_setup` (tipo biometria + sucesso)
  - `app_crash` (stack trace anônimo)
  - `api_error` (endpoint + status code)
  - `performance_slow` (operação + duração em ms)

**Arquivo**: `AnalyticsManager.swift` (novo)
```swift
struct AnalyticsManager {
    static func logEvent(_ name: String, parameters: [String: Any]? = nil)
    static func logLoginAttempt(success: Bool, method: String) // password/biometric
    static func logApiError(endpoint: String, statusCode: Int)
}
```

#### 5.2 Crash Reporting
- **Ferramenta**: Sentry ou Firebase Crashlytics
- **Dados coletados**:
  - Stack trace (com source map)
  - Breadcrumbs (últimas 5 ações do usuário)
  - Device info (model, iOS version, available memory)
  - User ID (anônimo)
- **Alertas**: Notificar team se crash rate > 1%

#### 5.3 Performance Monitoring
- **Uso de `PerformanceMonitor` já criado**
- **Endpoints monitorados**:
  - Login API (target: < 2s)
  - Refresh token (target: < 500ms)
  - Biometric authentication (target: < 1s)
- **App metrics**:
  - Memory footprint (target: < 100MB)
  - Startup time (target: < 2s cold start)
  - Frame rate (target: 60 FPS)

#### 5.4 Database Optimization
- **Local**: Armazenar user preferences + offline cache em SQLite
  - Email validation history (para cache)
  - Biometric setup state
  - Session timestamps
- **Schema**: Simples, indexed por email

**Arquivo**: `LocalDatabase.swift` (novo) - usando GRDB ou Core Data

#### 5.5 Network Optimization
- **HTTP/2**: Usar HTTP/2 em todos endpoints (via URLSession)
- **Compression**: Gzip response bodies
- **Caching**: HTTP cache headers apropriados (Cache-Control, ETag)
- **Batching**: Combinar múltiplas requisições quando possível

#### 5.6 Testes & Benchmarks
- Load testing: 1000 concurrent logins/segundo
- Memory profiling: Verificar leaks com Instruments
- Battery impact: Monitorar com Energy Impact
- Network: Testar com throttling (3G, 4G, LTE)

**Timeline**: Semanas 8-9
**Owner**: DevOps + iOS Team

---

## 🎨 Phase 6: UI/UX Polish & App Store Submission (2 semanas)

**Objetivo**: Polir interface, testes finais, e submeter para App Store.

### Tarefas

#### 6.1 UI/UX Enhancements
- **Onboarding**: Criar tela de boas-vindas com explicação de segurança biométrica
  - "Por que pedimos biometria?"
  - "Como seus dados são protegidos?"
  - Skip para usuários já autenticados

**Arquivo**: `OnboardingView.swift` (novo)

- **Temas**: Verificar light/dark mode em todas as telas
  - LoginView ✅ (já tem theme toggle)
  - ForgotPasswordView ✅
  - ReauthenticationView ✅
  - Add ProfileView dark mode fix se necessário

- **Acessibilidade**: 
  - VoiceOver support (labels em ImageButtons)
  - Dynamic font sizes (min 12pt, max 32pt)
  - Color contrast ratio (WCAG AA: 4.5:1 para texto)
  - Tester: Ligar VoiceOver + testar flow completo

#### 6.2 Localization (i18n)
- **Idiomas**: Português (BR) + Inglês (US) no mínimo
- **Strings**: Extrair todas strings hardcoded para `Localizable.strings`
  - "Email inválido" → pt-BR: "Email inválido", en-US: "Invalid email"
  - "Senha inválida" → pt-BR: "Senha inválida", en-US: "Invalid password"
  - Etc. (~50 strings)
- **Dates**: Usar locale apropriado (dd/MM/yyyy vs MM/dd/yyyy)
- **Numbers**: Usar locale-aware NumberFormatter

**Arquivo**: `Localizable.strings` (Português), `Localizable.strings` (Inglês)

#### 6.3 Final Testing
- **Smoke Tests**: Verificar cada tela carrega
  - LoginView: Email input + Password input + Login button ✅
  - ForgotPasswordView: Email + Nova senha + PasswordStrength ✅
  - MainTabView: Tabs navegam ✅
  - ProfileView: Logout funciona ✅
  - ReauthenticationView: Biometria funciona ✅

- **Security Tests**:
  - Login com email duplicado → rejeitado ✅
  - 5 tentativas falhadas → lockout 5 min ✅
  - Logout → biometria limpa ✅
  - App em background 30s → pede re-auth ✅

- **Device Testing**: Rodar em:
  - iPhone 14 Pro (latest)
  - iPhone 13 mini (antigo)
  - iPad Air (tablet)
  - Testar com network throttling (3G)

- **iOS Versions**: Testar em iOS 16.6, 17.0, 18.0 (target >= 16.6)

#### 6.4 App Store Submission
- **App Name**: "EasyFly" ✅
- **Icon**: 1024x1024 PNG (airplane theme) → criar/obter
- **Screenshots**: 5x (en-US) + 5x (pt-BR)
  - Screenshot 1: Login screen com email/password
  - Screenshot 2: Biometric setup
  - Screenshot 3: Main app (flights)
  - Screenshot 4: Profile com logout
  - Screenshot 5: Security features
- **Description**:
  - "Secure flight booking app with biometric authentication"
  - Mencionar: Encryption, SHA-256, PBKDF2, Rate limiting, 2FA
- **Keywords**: flight, booking, biometric, security, authentication
- **Privacy Policy**: Publicar em website (mencionar: dados não coletados, apenas stored localmente)
- **Terms of Service**: Publicar em website

**App Store Metadata**:
```
Bundle ID: com.easyfly.app
Category: Travel
Minimum OS: iOS 16.6
Supported devices: iPhone (4.7"+)
Rating: 17+ (no offensive content, but security-focused app)
```

#### 6.5 Build & Code Signing
- **Provisioning Profile**: Development → Production
  - Xcode: Manage Certificates → Apple ID login
  - Export: Ad Hoc ou App Store distribution
  - Code sign: Automatic signing enabled

- **Release Build**:
```bash
xcodebuild -scheme EasyFly -configuration Release \
  -derivedDataPath build -archivePath build/EasyFly.xcarchive archive
```

- **Notarization**: Apple requer notarização para distribuição (Mac only, iOS não precisa)

#### 1.0 Documentation
- **README.md**: Como rodar localmente, setup do Xcode

---

## 📅 Cronograma Consolidado

| Fase | Semanas | Datas (est.) | Status | Owner |
|------|---------|--------------|--------|-------|
| Phase 1 | 4 | Out 2025 | ✅ Completo | Mobile |
| Phase 2 | 4 | Nov 2025 | ✅ Completo | Security and Fixed Bugs |
| Phase 3 | 4 | Fev 2026 | 🚀 Em Planejamento | Backend + Mobile |
| Phase 4 | 3 | Mar 2026 | 🚀 Em Planejamento | Security + Mobile |
| Phase 5 | 2 | Out 2026 | 🚀 Em Planejamento | DevOps + Mobile |
| Phase 6 | 2 | Nov 2026 | 🚀 Em Planejamento | Product + QA |

**Alvo de Lançamento**: Nov 2026 (App Store)

### Performance
- Cold start: < 2s
- Login: < 2s
- Biometric auth: < 1s
- Memory: < 100MB (avg), < 150MB (peak)
- Battery: < 5% drain/hour (idle)

### Compatibility
- iOS: 16.6+ (iPhone 8+)
- Devices: iPhone only
- Orientations: Portrait + Landscape
- Dark mode: Full support

---

**Próximo Review**: 15 Dezembro 2025 (validar Phase 3 requirements)
