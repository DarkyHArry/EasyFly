import SwiftUI
import SwiftData

@main
struct EasyFlyApp: App {
    // Provide a SwiftData model container so views using @Query/@Model work at runtime
    @StateObject private var lifecycleManager = AppLifecycleManager.shared
    var modelContainer: ModelContainer
    
    init() {
        do {
            self.modelContainer = try ModelContainer(for: Item.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .modelContainer(modelContainer)
        }
    }
}
