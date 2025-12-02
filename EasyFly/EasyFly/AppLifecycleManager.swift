import Foundation
import UIKit
import os

/// Gerencia o ciclo de vida da aplicação e re-autenticação biométrica quando o app volta do background.
final class AppLifecycleManager: NSObject, ObservableObject {
    static let shared = AppLifecycleManager()
    
    @Published var shouldRequireReauth: Bool = false
    
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "AppLifecycle")
    private let userDefaults = UserDefaults.standard
    private var backgroundTime: Date?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        let notificationCenter = NotificationCenter.default
        
        // Quando app vai para background
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Quando app volta do background
        notificationCenter.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Quando app vai ser encerrado
        notificationCenter.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        backgroundTime = Date()
        os_log("App entered background at %@", log: logger, type: .info, Date().description)
    }
    
    @objc private func appWillEnterForeground() {
        // Se o app estava em background por mais de 30 segundos, pedir re-autenticação
        if let backgroundTime = backgroundTime {
            let timeInBackground = Date().timeIntervalSince(backgroundTime)
            os_log("App returned from background. Time away: %.0f seconds", log: logger, type: .info, timeInBackground)
            
            if timeInBackground > 30 {
                // Pedir re-autenticação por segurança
                shouldRequireReauth = true
                os_log("Re-authentication required (was in background for %.0f seconds)", log: logger, type: .warning, timeInBackground)
            }
        }
        self.backgroundTime = nil
    }
    
    @objc private func appWillTerminate() {
        backgroundTime = nil
    }
    
    /// Reseta o flag de re-autenticação após verificação bem-sucedida
    func resetReauthRequirement() {
        shouldRequireReauth = false
        backgroundTime = nil
        os_log("Re-authentication requirement reset", log: logger, type: .info)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
