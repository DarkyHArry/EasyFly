import SwiftUI

struct AppFlowView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedEmail") private var loggedEmail: String = ""
    @StateObject private var lifecycleManager = AppLifecycleManager.shared
    @State private var showReauthScreen = false

    var body: some View {
        ZStack {
            if isLoggedIn {
                if lifecycleManager.shouldRequireReauth && !showReauthScreen {
                    ReauthenticationView(
                        loggedEmail: loggedEmail,
                        onSuccess: {
                            showReauthScreen = true
                        }
                    )
                    .environmentObject(lifecycleManager)
                    .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .onAppear {
                            showReauthScreen = false
                        }
                }
            } else {
                LoginView(didLogin: {
                    withAnimation(.easeInOut) {
                        isLoggedIn = true
                    }
                })
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isLoggedIn)
        .environmentObject(lifecycleManager)
    }
}

struct AppFlowView_Previews: PreviewProvider {
    static var previews: some View {
        AppFlowView()
    }
}

